#!/usr/bin/env python3
"""Render NULL's original 96-second piano loop. Requires numpy, scipy, and imageio-ffmpeg.
Samples are fetched from a pinned CC0 library into builds/, never needed at runtime.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import hashlib
import subprocess
import urllib.request
import numpy as np
import imageio_ffmpeg
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
from scipy import signal

ROOT = Path(__file__).resolve().parents[1]
REVISION = '440300901dfe9275fd84e0b7763af1f8443ae62e'
SOURCE = f'https://raw.githubusercontent.com/sgossner/VSCO-2-CE/{REVISION}/'
RATE = 44100
SECONDS = 96
# Two four-beat bars per harmony, at 60 BPM. All notes and timing are original.
SCORE = [
    (38,45,[53,57,64],[76,69,77]), (34,41,[50,57,65],[74,69,72]),
    (41,48,[53,57,64],[67,72,76]), (36,43,[55,62,67],[74,67,76]),
    (31,38,[53,58,65],[70,74,69]), (33,40,[50,57,64],[77,76,74]),
    (39,46,[55,58,62],[67,70,74]), (33,40,[55,62,64],[74,71,76]),
    (38,45,[53,57,64],[69,76,74]), (34,41,[50,57,65],[72,74,69]),
    (41,48,[53,57,64],[76,72,67]), (36,43,[55,62,67],[74,69,None]),
]
SAMPLES = {6: '10e0e1c3ec485c50bf12f7e2400e8aa9364f2bc9', 8: 'cb2e89a7749fc4b979512aa5da883059cd3f6ad7', 10: '2b3b3f25903ed087eb334d985a0b25f4bbd510d4', 12: '5942615eb10199382e44c0e052ebb7885b167f53', 14: '30127aa63c8342a363b9a13b8052a3428d3bb046', 16: '480e9d56f8cfaefde9be4a7f9bde2b01ac3d100f', 18: '90745e10b1d8774db29a9817a218277102cd998b', 20: '084b3f131592beecd311b309e6c5f42190653f4f', 22: 'a4238a2d033e560225a1b3d9d3fa1eef9c21ac50', 24: '6350b1cf0a614fe0920ad212e807d4575fcf71bd', 26: '9a6cd6b879752f747e136ee001e7f1b78b40dc9c', 28: 'c371f48ff5e5a675a0d91d0e7060e79322adfc2e'}


def fetch_sample(item):
    index, expected = item
    path = ROOT / 'builds/music-samples' / f'Player_dyn1_rr1_{index:03}.wav'
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        url = SOURCE + f'Keys/Upright%20Piano/{path.name}'
        with urllib.request.urlopen(url, timeout=45) as response:
            path.write_bytes(response.read())
    raw = path.read_bytes()
    actual = hashlib.sha1(f'blob {len(raw)}\0'.encode() + raw).hexdigest()
    if actual != expected:
        raise ValueError(f'Sample checksum mismatch: {path.name}')
    decoded = subprocess.run([FFMPEG,'-v','error','-i',str(path),'-f','f32le','-ar',str(RATE),'-ac','2','pipe:1'],
                             check=True, stdout=subprocess.PIPE).stdout
    audio = np.frombuffer(decoded, dtype='<f4').reshape(-1,2).copy()
    peak = np.max(np.abs(audio))
    onset = np.flatnonzero(np.max(np.abs(audio),axis=1) > peak * .003)[0]
    audio = audio[max(0,onset-round(.003*RATE)):]
    return 21 + index * 2, audio / peak


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT/'assets/audio/still-orbit.ogg')
    args = parser.parse_args()
    with ThreadPoolExecutor(max_workers=4) as pool:
        samples = dict(pool.map(fetch_sample, SAMPLES.items()))
    rng = np.random.default_rng(1102)
    frames = RATE * SECONDS
    dry = np.zeros((frames,2),dtype=np.float32)
    note_cache = {}

    def place(midi, when, gain, hold):
        if midi is None:
            return
        if midi not in note_cache:
            root = min(samples, key=lambda n: abs(n-midi))
            source = samples[root]
            position = np.arange(0, len(source)-1, 2**((midi-root)/12))
            base = np.arange(len(source))
            note_cache[midi] = np.column_stack([np.interp(position,base,source[:,ch]) for ch in range(2)]).astype(np.float32)
        note = note_cache[midi][:round(hold*RATE)].copy()
        attack = min(round(.012*RATE),len(note))
        release = min(round(.8*RATE),len(note))
        note[:attack] *= np.linspace(0,1,attack,dtype=np.float32)[:,None]
        note[-release:] *= np.linspace(1,0,release,dtype=np.float32)[:,None]**2
        pan = np.clip(.5 + (midi-58)*.004, .37,.63)
        note *= np.array([np.cos(pan*np.pi/2),np.sin(pan*np.pi/2)]) * 2**.5 * gain * rng.uniform(.9,1.06)
        start = round((when+rng.uniform(-.035,.035)) * RATE) % frames
        count = min(len(note),frames-start)
        dry[start:start+count] += note[:count]
        if count < len(note): dry[:len(note)-count] += note[count:]

    for i,(bass,fifth,inner,melody) in enumerate(SCORE):
        t = i*8 + .55
        place(bass,t,.25,7.8)
        place(fifth,t+4.35,.13,6.2)
        for note,offset in zip(inner,[.8,2.55,5.45]): place(note,t+offset,.16,5.5)
        for note,offset in zip(melody,[1.8,3.95,6.35]): place(note,t+offset,.21,4.8)

    # Render steady-state tails before extracting a whole cycle: no fade-to-silence seam.
    warm = np.tile(dry,(3,1))
    impulse_frames = round(6.5*RATE)
    time = np.arange(impulse_frames)/RATE
    wet = np.empty_like(warm)
    for ch in range(2):
        impulse = rng.normal(0,1,impulse_frames).astype(np.float32)
        impulse = signal.sosfilt(signal.butter(2,2400,fs=RATE,output='sos'),impulse)
        impulse *= np.exp(-1.2*time)
        impulse[:round(.035*RATE)] = 0
        impulse /= np.sqrt(np.sum(impulse**2))
        for delay,level in [(.071,.16),(.137,.11),(.223,.08),(.367,.05)]:
            impulse[round((delay+ch*.007)*RATE)] += level
        wet[:,ch] = signal.fftconvolve(warm[:,ch],impulse.astype(np.float32))[:len(warm)]
    mixed = warm*.86 + wet*.23
    filtered = signal.sosfilt(signal.butter(2,40,'highpass',fs=RATE,output='sos'),mixed,axis=0)
    filtered = signal.sosfilt(signal.butter(2,5600,fs=RATE,output='sos'),filtered,axis=0)
    loop = filtered[frames:frames*2].astype(np.float32)
    peak = float(np.max(np.abs(loop)))
    rms = float(np.sqrt(np.mean(loop**2)))
    loop *= min(10**(-3/20)/peak,10**(-23/20)/rms)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run([FFMPEG,'-y','-v','error','-f','f32le','-ar',str(RATE),'-ac','2','-i','pipe:0',
                    '-c:a','libvorbis','-q:a','6','-metadata','TITLE=Still Orbit','-metadata','ARTIST=NULL',
                    '-metadata','COMMENT=Original NULL composition; CC0 VSCO 2 CE upright piano.',str(args.output)],
                   input=loop.astype('<f4').tobytes(),check=True)
    # A convenient local listening preview, excluded from source control.
    subprocess.run([FFMPEG,'-y','-v','error','-i',str(args.output),'-t','24',str(ROOT/'builds/still-orbit-preview.wav')],check=True)
    step = float(np.max(np.abs(loop[0]-loop[-1])))
    assert np.isfinite(loop).all() and np.max(np.abs(loop)) < .72 and step < .01
    print(f'{args.output.name}: {SECONDS}s stereo; peak {20*np.log10(np.max(np.abs(loop))):.1f} dBFS; '
          f'RMS {20*np.log10(np.sqrt(np.mean(loop**2))):.1f} dBFS; seam step {step:.6f}; {args.output.stat().st_size:,} bytes')


if __name__ == '__main__':
    main()
