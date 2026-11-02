"""Still Orbit score revisions, shared by audio and notation exports."""

ORIGINAL_SCORE = [
    (38,45,[53,57,64],[76,69,77]), (34,41,[50,57,65],[74,69,72]),
    (41,48,[53,57,64],[67,72,76]), (36,43,[55,62,67],[74,67,76]),
    (31,38,[53,58,65],[70,74,69]), (33,40,[50,57,64],[77,76,74]),
    (39,46,[55,58,62],[67,70,74]), (33,40,[55,62,64],[74,71,76]),
    (38,45,[53,57,64],[69,76,74]), (34,41,[50,57,65],[72,74,69]),
    (41,48,[53,57,64],[76,72,67]), (36,43,[55,62,67],[74,69,None]),
]

# A four-note descending motif, over the same four harmonies in three phrases.
SCORE = [
    (38,45,[50,53,57],[69,67,65,64]), (34,41,[50,53,58],[69,67,65,62]),
    (41,48,[48,53,57],[69,67,65,64]), (36,43,[48,52,55],[67,65,64,62]),
    (38,45,[50,53,57],[69,67,65,64]), (34,41,[50,53,58],[69,67,65,62]),
    (41,48,[48,53,57],[69,70,69,67]), (36,43,[48,52,55],[67,65,64,62]),
    (38,45,[50,53,57],[69,67,65,64]), (34,41,[50,53,58],[69,67,65,62]),
    (41,48,[48,53,57],[69,67,65,64]), (36,43,[48,52,55],[67,65,64,62]),
]

# An airy third arrangement: a slow arch, a common A3 pulse, and open voicings.
AIR_SCORE = [
    (38,45,[50,57,64],[69,71,76]), (43,50,[55,57,64],[74,71,69]),
    (35,42,[54,57,62],[66,69,71]), (33,40,[52,57,59],[71,69,64]),
    (38,45,[50,57,64],[69,71,76]), (43,50,[55,57,64],[74,71,69]),
    (35,42,[54,57,62],[71,69,66]), (33,40,[52,57,59],[69,71,69]),
    (38,45,[50,57,64],[69,71,76]), (43,50,[55,57,64],[74,71,69]),
    (35,42,[54,57,62],[66,69,71]), (33,40,[52,57,59],[71,69,64]),
]


def events(revision='revised'):
    """Nominal attacks in renderer order, before deterministic humanization."""
    if revision not in ['original', 'revised', 'air']:
        raise ValueError('Unknown score revision: ' + revision)
    original = revision == 'original'
    airy = revision == 'air'
    score = ORIGINAL_SCORE if original else (AIR_SCORE if airy else SCORE)
    result = []
    for index, (bass, fifth, inner, melody) in enumerate(score):
        start = index * 8 + (.55 if original else .10)
        dynamic = 1.0 if original else ([.88, .94, .90] if airy else [.94, 1.0, .91])[index // 4]
        rows = [('bass', bass, 0, .25 if original else .22, 7.8 if original else 5.6),
                ('fifth', fifth, 4.35 if original else 4, .13 if original else .10, 6.2 if original else 3.4)]
        if original:
            rows += [('inner', note, offset, .16, 5.5) for note, offset in zip(inner, [.8, 2.55, 5.45])]
            rows += [('melody', note, offset, .21, 4.8) for note, offset in zip(melody, [1.8, 3.95, 6.35])]
        elif airy:
            rows = [('bass', bass, 0, .16, 6.8), ('fifth', fifth, 4, .07, 3.5)]
            rows += [('inner', inner[1], offset, .055, min(1.25, 7.8-offset)) for offset in [1,3,5,7]]
            rows += [('melody', note, offset, .12, min(2.5, 7.8-offset))
                     for note, offset in zip(melody, [0,3,6])]
        else:
            rows += [('inner', inner[n], offset, .105, min(1.7, 7.8-offset))
                     for n, offset in zip([0, 1, 2, 1], [1, 3, 5, 7])]
            rows += [('melody', note, offset, .19, 1.8) for note, offset in zip(melody, [0, 2, 4, 6])]
        for role, pitch, offset, gain, hold in rows:
            if pitch is not None:
                result.append(dict(role=role, pitch=pitch, when=start+offset,
                                   gain=gain*dynamic, hold=hold, block=index))
    return result
