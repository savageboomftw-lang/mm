# Afterhours

A Pastel Ghost–style dream-pop / chillwave song with FNAF-themed lyrics, sung from the animatronic's point of view.
100 BPM, A♭ major, chords A♭ – E♭ – Fm – D♭, one chord per lyric line (9.6 s).

- `afterhours_full.mp3`: current full mix (5:12, mastered to −14 LUFS) with verse 1, the pre-chorus and the chorus vocals.
- `afterhours_instrumental.mp3`: the same mix without vocals; record new parts over this.
- `recordings/`: the raw vocal takes (verse 1 + pre-chorus, and the chorus).

## Structure

| Time | Section | Vocals |
|---|---|---|
| 0:00 | Intro (piano hook) | — |
| 0:19 | Verse 1 + pre-chorus | recorded, muffled "behind the bathroom door" |
| 1:17 | Chorus 1 | recorded, the door opens: clear, airy, double-tracked |
| 1:55 | Alarm interlude (tape-stop in) | — |
| 2:14 | Verse 2 + pre-chorus | not recorded yet |
| 3:12 | Chorus 2 | chorus take reused |
| 3:50 | Bridge | not recorded yet |
| 4:10 | Final chorus | chorus take reused |
| 4:48 | Outro | — |

## Lyrics

**Verse 1:** Pastel lights on an empty stage / I still hum the birthday song / Tape loops play to the dark again / Waiting for you all night long
**Pre-chorus:** Little hands, a paper crown / Where did all the laughter go?
**Chorus:** Stay till six, stay with me / I'm not what I used to be / Close your eyes, it's only me / Humming you back to sleep
**Verse 2:** Static snow on the camera feed / Footsteps soft as falling dust / Every smile was painted on / Every song is turning rust
**Pre-chorus 2:** Wind me up, the music box / Plays the tune you can't forget
**Bridge:** When the bell rings out at six / I'll be gone, but I'll be here

## Rebuilding (`scripts/`)

These are Python scripts that need numpy, scipy, librosa, soundfile and pyloudnorm. Run them from one working folder.

1. `song_pg3.py` renders the instrumental (`pg3_premaster.wav`). Its match-EQ step reads a reference recording from `song/s.wav`. That file isn't included because it's someone else's copyrighted track; use any reference, or remove the match-EQ block.
2. `master.py in.wav out.wav` applies the brightness trim, normalises to −14 LUFS and limits the peaks.
3. Vocals:
   - `tune2.py` and `tune3.py` apply gentle pitch correction to `rec2/src.wav` (verse) and `rec3/src.wav` (chorus); convert the takes in `recordings/` to those WAVs first.
   - `pastel_voice2.py` and `pastel_voice3.py` add the vocoder and whisper layers.
   - `mix_full.py bathroom unused 0.55 song_premaster.wav .05 pg3_premaster.wav` places every line and applies the bathroom/door effects.
   - Then run `master.py`.
