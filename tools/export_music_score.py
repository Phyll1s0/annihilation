#!/usr/bin/env python3
"""Export the original and revised Still Orbit scores and a comparison PDF.

Requires verovio, cairosvg, matplotlib, mido, reportlab, and pypdf.
The reading score shortens gates and rounds old onsets to eighth notes;
the MIDI files and timing charts retain the renderer's longer note gates.
"""
from collections import defaultdict
from io import BytesIO
from pathlib import Path
import argparse
import csv
import json
import xml.etree.ElementTree as ET
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import cairosvg
import mido
import verovio
from pypdf import PdfReader, PdfWriter, Transformation
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from music_score import events, ORIGINAL_SCORE, SCORE

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/pdf'
WORK = ROOT / 'builds/music-score'
NAMES = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B']
COLORS = {'melody': '#356696', 'inner': '#8b9199', 'bass': '#568277', 'fifth': '#568277'}


def pitch_name(pitch):
    return NAMES[pitch % 12] + str(pitch // 12 - 1)


def text(parent, tag, value, **attrs):
    element = ET.SubElement(parent, tag, attrs)
    element.text = str(value)
    return element


def reading_xml(revision, first=0, count=24):
    root = ET.Element('score-partwise', version='4.0')
    parts = [('melody', 'Melody', 'G', '2'), ('inner', 'Inner tones', 'F', '4'), ('bass', 'Bass', 'F', '4')]
    listing = ET.SubElement(root, 'part-list')
    for part_id, name, _, _ in parts:
        entry = ET.SubElement(listing, 'score-part', id=part_id)
        text(entry, 'part-name', name)
        text(entry, 'part-abbreviation', name)
    grouped = defaultdict(list)
    origin = .55 if revision == 'original' else .10
    for event in events(revision):
        onset = round((event['when'] - origin) * 2)
        part_id = 'bass' if event['role'] == 'fifth' else event['role']
        grouped[(part_id, onset // 8)].append((onset % 8, event))
    for part_id, _, sign, line in parts:
        part = ET.SubElement(root, 'part', id=part_id)
        for bar in range(first, first + count):
            measure = ET.SubElement(part, 'measure', number=str(bar + 1))
            if bar == first:
                attrs = ET.SubElement(measure, 'attributes')
                text(attrs, 'divisions', 2)
                key = ET.SubElement(attrs, 'key')
                text(key, 'fifths', 2 if revision == 'air' else -1)
                text(key, 'mode', 'major' if revision == 'air' else 'minor')
                meter = ET.SubElement(attrs, 'time')
                text(meter, 'beats', 4)
                text(meter, 'beat-type', 4)
                clef = ET.SubElement(attrs, 'clef')
                text(clef, 'sign', sign)
                text(clef, 'line', line)
            cursor = 0

            def rest(ticks):
                nonlocal cursor
                # Plain eighth/quarter/half rests avoid awkward dotted notation.
                for duration in [4, 2, 1]:
                    while ticks >= duration:
                        note = ET.SubElement(measure, 'note')
                        ET.SubElement(note, 'rest')
                        text(note, 'duration', duration)
                        text(note, 'type', {4: 'half', 2: 'quarter', 1: 'eighth'}[duration])
                        cursor += duration
                        ticks -= duration

            for onset, event in sorted(grouped[(part_id, bar)], key=lambda row: row[0]):
                rest(onset - cursor)
                duration = 1 if part_id == 'inner' else (4 if event['role'] == 'bass' else 2)
                duration = min(duration, 8 - onset)
                note = ET.SubElement(measure, 'note', color=COLORS[part_id])
                pitch = ET.SubElement(note, 'pitch')
                name = NAMES[event['pitch'] % 12]
                text(pitch, 'step', name[0])
                alter = -1 if 'b' in name else (1 if '#' in name else 0)
                if alter:
                    text(pitch, 'alter', alter)
                text(pitch, 'octave', event['pitch'] // 12 - 1)
                text(note, 'duration', duration)
                text(note, 'type', {4: 'half', 2: 'quarter', 1: 'eighth'}[duration])
                if name == 'Eb':
                    text(note, 'accidental', 'flat')
                if name == 'B' and revision != 'air':
                    text(note, 'accidental', 'natural')
                if part_id == 'melody':
                    lyric = ET.SubElement(note, 'lyric')
                    text(lyric, 'text', pitch_name(event['pitch']))
                cursor += duration
            rest(8 - cursor)
            assert cursor == 8
    return ET.tostring(root, encoding='unicode', xml_declaration=True)


def midi_and_csv(revision):
    notes = events(revision)
    rng = np.random.default_rng(1102)
    performed = []
    for event in notes:
        strength = rng.uniform(.9, 1.06) if revision == 'original' else rng.uniform(.96, 1.04)
        jitter = rng.uniform(-.035, .035) if revision == 'original' else rng.uniform(-.015, .015)
        performed.append({**event, 'onset': event['when'] + jitter, 'velocity': round(90 * event['gain'] / .25 * strength)})
    midi = mido.MidiFile(ticks_per_beat=1000)
    tempo = mido.MidiTrack()
    tempo.append(mido.MetaMessage('set_tempo', tempo=1000000))
    tempo.append(mido.MetaMessage('marker', text='Loop start'))
    tempo.append(mido.MetaMessage('marker', text='96-second loop end; note tails may continue', time=96000))
    midi.tracks.append(tempo)
    for channel, role in enumerate(['bass', 'fifth', 'inner', 'melody']):
        track = mido.MidiTrack()
        track.append(mido.MetaMessage('track_name', name=role))
        track.append(mido.Message('program_change', channel=channel, program=0))
        messages = []
        for event in performed:
            if event['role'] != role:
                continue
            messages.append((round(event['onset'] * 1000), mido.Message('note_on', channel=channel, note=event['pitch'], velocity=event['velocity'])))
            messages.append((round((event['onset'] + event['hold']) * 1000), mido.Message('note_off', channel=channel, note=event['pitch'], velocity=0)))
        previous = 0
        for tick, message in sorted(messages, key=lambda row: (row[0], row[1].type == 'note_on')):
            track.append(message.copy(time=tick-previous))
            previous = tick
        midi.tracks.append(track)
    path = OUT / f'still-orbit-{revision}.mid'
    midi.save(path)
    assert sum(message.type == 'note_on' for track in mido.MidiFile(path).tracks for message in track) == len(notes)
    with (OUT / f'still-orbit-{revision}-notes.csv').open('w') as handle:
        writer = csv.writer(handle, lineterminator='\n')
        writer.writerow(['layer', 'pitch', 'onset_seconds', 'gate_seconds'])
        for event in performed:
            writer.writerow([event['role'], pitch_name(event['pitch']), f"{event['onset']:.4f}", f"{event['hold']:.4f}"])


def statistics(revision):
    notes = events(revision)
    melody = [event['pitch'] for event in notes if event['role'] == 'melody']
    intervals = np.diff(melody)
    peak = max(sum(any(e['when'] + shift <= t < e['when'] + shift + e['hold']
                       for shift in [-96, 0]) for e in notes) for t in np.arange(0, 96, .05))
    return dict(melody_notes=len(melody), large_leaps=int(sum(abs(intervals) >= 5)), intervals=len(intervals), peak_gates=peak)


def roll(after='revised'):
    fig, axes = plt.subplots(2, 1, figsize=(8.4, 5.3), sharex=True, sharey=True)
    for ax, revision in zip(axes, ['original', after]):
        for block in range(3):
            if block % 2 == 0:
                ax.axvspan(block*8, (block+1)*8, color='#f2f4f5', zorder=0)
        for event in events(revision):
            for shift in [-96, 0]:
                start = event['when'] + shift
                end = start + event['hold']
                if end <= 0 or start >= 24:
                    continue
                ax.broken_barh([(max(0, start), min(24, end)-max(0, start))], (event['pitch']-.35, .7),
                               facecolors=COLORS[event['role']], alpha=.85 if event['role']=='melody' else .5)
        ax.set_title('Before - original gates' if revision=='original' else ('After - airy piano gates' if after=='air' else 'After - revised gates'), loc='left', fontsize=11, pad=8)
        ax.set_yticks([36, 48, 60, 72], ['C2', 'C3', 'C4', 'C5'])
        ax.set_ylim(30, 80)
        ax.set_xlim(0, 24)
        ax.set_xticks(range(0, 25, 4))
        ax.grid(axis='x', color='#dfe3e7', linewidth=.6)
        ax.tick_params(labelsize=8, length=0, pad=5)
        for edge in ax.spines.values():
            edge.set_visible(False)
    axes[-1].set_xlabel('Seconds in the loop (first 24 seconds)', fontsize=9)
    fig.tight_layout(h_pad=2)
    fig.savefig(WORK/'timing-map.pdf')
    fig.savefig(WORK/'timing-map.png', dpi=180)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--air', action='store_true', help='Export the current airy piano arrangement and its comparison')
    args = parser.parse_args()
    revisions = ['air'] if args.air else ['original', 'revised']
    after = 'air' if args.air else 'revised'
    page_count = len(revisions)*2+1
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    pdfmetrics.registerFont(TTFont('Poppins', str(ROOT/'assets/fonts/Poppins-Regular.ttf')))
    pdfmetrics.registerFont(TTFont('PoppinsLight', str(ROOT/'assets/fonts/Poppins-ExtraLight.ttf')))
    stats = {revision: statistics(revision) for revision in ['original', after]}
    (WORK/'statistics.json').write_text(json.dumps(stats, indent=2))
    figures = []
    for revision in revisions:
        (OUT/f'still-orbit-{revision}.musicxml').write_text(reading_xml(revision))
        midi_and_csv(revision)
        for first in range(0, 24, 4):
            toolkit = verovio.toolkit()
            toolkit.setOptions(dict(pageWidth=1800, pageHeight=1000, scale=40,
                                    adjustPageHeight=True, breaks='none', header='none', footer='none',
                                    pageMarginTop=60, pageMarginBottom=20, pageMarginLeft=0, pageMarginRight=0,
                                    spacingStaff=9))
            assert toolkit.loadData(reading_xml(revision, first, 4))
            assert toolkit.getPageCount() == 1
            svg = toolkit.renderToSVG(1)
            (WORK/f'{revision}-{first+1:02d}.svg').write_text(svg)
            data = cairosvg.svg2pdf(bytestring=svg.encode())
            figures.append(PdfReader(BytesIO(data)).pages[0])
    roll(after)
    width, height = A4
    document = BytesIO()
    doc = canvas.Canvas(document, pagesize=A4)
    title = 'Still Orbit - airy piano arrangement' if args.air else 'Still Orbit - original and revised scores'
    doc.setTitle(title)
    doc.setAuthor('NULL')
    placement = []
    for page in range(len(revisions)*2):
        revision = revisions[page//2]
        local_page = page % 2
        doc.setFillColorRGB(.12, .14, .16)
        doc.setFont('PoppinsLight', 27)
        doc.drawString(42, height-57, 'Still Orbit')
        doc.setFont('Poppins', 11)
        doc.drawRightString(width-42, height-54, 'CURRENT AIR' if args.air else ('BEFORE' if revision=='original' else 'AFTER'))
        doc.setFont('Poppins', 8)
        doc.setFillColorRGB(.38, .41, .44)
        doc.drawString(42, height-81, 'NULL  |  Piano study score  |  4/4  |  Quarter note = 60  |  96-second loop')
        doc.drawString(42, height-97, 'Reading reduction: original onsets rounded to eighth notes; written lengths shortened.')
        doc.drawString(42, height-110, 'Piano notes shown; the current mix also has a soft organ bed.' if args.air else 'Pitch names below the melody. MIDI and the final-page timing map preserve longer gates.')
        for index in range(3):
            first = local_page*12 + index*4
            top = height-145-index*207
            origin = .55 if revision=='original' else .10
            doc.setFont('Poppins', 9)
            doc.setFillColorRGB(.17, .23, .29)
            doc.drawString(42, top, f'Bars {first+1}-{first+4}  |  {first*4+origin:.2f}-{(first+4)*4+origin:.2f} s')
            source = figures[revisions.index(revision)*6 + first//4]
            scale = min((width-84)/float(source.mediabox.width), 178/float(source.mediabox.height))
            placement.append((page, source, scale, 42, top-14-float(source.mediabox.height)*scale))
        doc.setFont('Poppins', 7)
        doc.setFillColorRGB(.45, .48, .51)
        doc.drawString(42, 28, 'Reference signature: D major; soft organ tones are documented in the renderer.' if args.air else 'Reference signature: D minor; chromatic pitches in the original are retained.')
        doc.drawRightString(width-42, 28, f'{page+1} / {page_count}')
        doc.showPage()
    doc.setFont('PoppinsLight', 25)
    doc.setFillColorRGB(.12, .14, .16)
    doc.drawString(42, height-58, 'What changed')
    doc.setFont('Poppins', 9)
    doc.drawString(42, height-83, 'Blue = melody   |   Gray = inner tones   |   Green = bass and fifth')
    doc.setFont('Poppins', 8)
    doc.setFillColorRGB(.38, .41, .44)
    doc.drawString(42, height-100, 'Bars show nominal note gates before acoustic decay/reverb. Earlier-loop tails are included.')
    timing = PdfReader(WORK/'timing-map.pdf').pages[0]
    scale = (width-84)/float(timing.mediabox.width)
    placement.append((page_count-1, timing, scale, 42, height-120-float(timing.mediabox.height)*scale))
    y = 350
    explanations = [
        ('Melodic shape', f"Before: {stats['original']['large_leaps']} of {stats['original']['intervals']} melody intervals jump at least five semitones.",
         f"After: {stats[after]['large_leaps']} of {stats[after]['intervals']}; " + ('the A-B-E arch returns with small variations.' if args.air else 'the A-G-F-E motif returns with small variations.')),
        ('Room between notes', 'Before: melody gates last 4.8 s, with up to three melody notes overlapping.',
         f"After: {'2.5 s gates with a shorter final note' if args.air else '1.8 s gates on a 2 s pulse'}. Peak piano gates: {stats['original']['peak_gates']} -> {stats[after]['peak_gates']}."),
        ('Harmonic continuity', 'Before: D / Bb / F / C / G / A / Eb / A / D / Bb / F / C bass roots.',
         'After: D / G / B / A repeated three times, with a common A3 piano pulse.' if args.air else 'After: D / Bb / F / C repeated three times; no sudden Eb bass or B-natural detour.'),
        ('Reverb', 'Before: 6.5 s impulse buffer; exponential decay factor 1.2; wet mix 0.23.',
         'After: bass-filtered reverb at 0.13; soft organ bed at 12% of piano RMS.' if args.air else 'After: 4.0 s buffer; faster decay factor 2.6; lower wet mix 0.14.'),
    ]
    for heading, before, after in explanations:
        doc.setFillColorRGB(.15, .20, .25)
        doc.setFont('Poppins', 11)
        doc.drawString(42, y, heading)
        doc.setFillColorRGB(.34, .37, .40)
        doc.setFont('Poppins', 8)
        doc.drawString(42, y-18, before)
        doc.drawString(42, y-32, after)
        y -= 79
    doc.setFont('Poppins', 7)
    doc.drawString(42, 28, 'Gate counts describe piano scheduling; organ tones and acoustic reverb are not counted.' if args.air else 'Gate counts describe synthesis scheduling, not equally loud sustained notes.')
    doc.drawRightString(width-42, 28, f'{page_count} / {page_count}')
    doc.save()
    writer = PdfWriter()
    for page in PdfReader(BytesIO(document.getvalue())).pages:
        writer.add_page(page)
    for page_index, source, scale, x, y in placement:
        writer.pages[page_index].merge_transformed_page(source, Transformation().scale(scale).translate(x, y))
    writer.add_metadata({'/Title': title, '/Author': 'NULL'})
    target = OUT/('still-orbit-air-score.pdf' if args.air else 'still-orbit-score.pdf')
    writer.write(target)
    result = PdfReader(target)
    assert len(result.pages)==page_count and 'What changed' in result.pages[-1].extract_text()
    for revision in revisions:
        expected = len([e for e in events(revision) if e['role']=='melody'])
        root = ET.parse(OUT/f'still-orbit-{revision}.musicxml').getroot()
        assert len(root.find("part[@id='melody']").findall('measure')) == 24
        assert len(root.find("part[@id='melody']").findall('.//pitch')) == expected
    print(target)
    print(json.dumps(stats, indent=2))


if __name__ == '__main__':
    main()
