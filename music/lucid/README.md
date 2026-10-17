# Lucid (paused)

A dream/sleep song in the style of Pastel Ghost's "Iris". It's at 108 BPM in F minor, with the chords D♭maj7 → E♭6 → Cm7 → Fm9, one chord per slot (4.44 s).

`lucid_instrumental.mp3` is the current instrumental (3:55, mastered to −14 LUFS). It has no vocals yet.

Sections: intro 0:00, verse 1 0:18, chorus 1 0:53, break 1:29, verse 2 1:38, chorus 2 2:13, break 2:49, chorus 3 2:58, outro 3:33.

## Lyrics

**Verse 1:** Counting sheep in the ceiling glow / Clocks melt slowly to the floor / I can hear the tide come in / Someone's knocking on a door
**Chorus** (one phrase per hook phrase, every 4.4 s): Don't wake me up / I'm almost there / through violet air / Stay here with me / Don't wake me up / I'm almost home / lost in the light / Let it be
**Verse 2:** Paper stars in a pastel sky / Every room a different year / Voices call me from the stairs / But I'm not ready to be here

The hook melody sits at C5–F6. Sing it two octaves lower; if F4 is out of reach, put the climax words "Stay" and "Let" on C4.

## Rebuilding

Run `scripts/dream4.py` to render `dream4_premaster.wav`, then `scripts/master_air.py dream4_premaster.wav out.wav`.

The match-EQ step needs a reference recording at `iris/s.wav`. It isn't included because it's someone else's copyrighted track; supply your own or remove that block.
