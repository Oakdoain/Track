# Pixabay Audio Assets

The audio files listed here were downloaded directly from the `AudioObject.contentUrl`
published on the corresponding Pixabay asset page. Pixabay and the listed creators do
not participate in or endorse this project.

Download date: 2026-07-19

## Incoming call ring

- Name: Cellphone ringing
- Creator: jourblue (Freesound), distributed on Pixabay as `freesound_community`
- Source: Pixabay
- Asset page: https://pixabay.com/sound-effects/technology-cellphone-ringing-6475/
- License: Pixabay Content License
- Original project file: `assets/audio/source/pixabay_cellphone_ringing_6475.mp3`
- Original SHA-256: `BF0AA4C887E1D0A40ACFFACC70C310C19CE9F320D69A5BD0E40923753F411D7A`
- Runtime project file: `assets/audio/ui/phone/incoming_ring_loop.ogg`
- Project use: incoming call ringtone
- Processing: only 00:00.000-00:02.000 is used. Audio after 00:02.000 is not used. A 40 ms fade-in and fade-out are applied before looping.

## Outgoing call ringback

- Name: Phone Ringing
- Creator: DRAGON-STUDIO
- Source: Pixabay
- Asset page: https://pixabay.com/sound-effects/film-special-effects-phone-ringing-382734/
- License: Pixabay Content License
- Original project file: `assets/audio/source/pixabay_phone_ringing_382734.mp3`
- Original SHA-256: `5284FB88D74BFF84DC2A42EEA44ED0A24B41BFF36731726034B89CB20202FDA7`
- Runtime project file: `assets/audio/ui/phone/outgoing_ringback.ogg`
- Project use: ringback while waiting for an outgoing call to be answered
- Processing: converted to Ogg Vorbis with a 40 ms fade-in; looping and stop fade are controlled by the phone audio state manager.

## Node text typing bed

- Name: Keyboard Typing
- Creator: Trollarch2 (Freesound), distributed on Pixabay as `freesound_community`
- Source: Pixabay
- Asset page: https://pixabay.com/sound-effects/technology-keyboard-typing-5997/
- License: Pixabay Content License
- Original project file: `assets/audio/source/pixabay_keyboard_typing_5997.mp3`
- Original SHA-256: `AC74E5A22D87E2617F5545D29D605774E4DDACA6DE4551E61D004D3C0BE80054`
- Runtime project file: `assets/audio/ui/text/node_typing_loop.ogg`
- Project use: low-volume sound bed during a node's first text reveal
- Processing: 00:00.500-00:03.500 is used, with a 40 ms fade-in and fade-out before looping.

See `PIXABAY_CONTENT_LICENSE.md` in this directory for the recorded license access details.

## Tutorial attention tick

- Name: New Notification 019
- Creator: Universfield (confirmed from the Pixabay page's structured `AudioObject.creator` data)
- Source: Pixabay
- Asset page: https://pixabay.com/sound-effects/film-special-effects-new-notification-019-363747/
- License: Pixabay Content License
- Download date: 2026-07-20
- Original project file: `assets/audio/source/pixabay_new_notification_019_363747.mp3`
- Original SHA-256: `94A220F81E5792295279DCF8AFAD1BF6BD24C690A9952EB538EE35DB03EA5182`
- Runtime project file: `assets/audio/ui/tutorial/tutorial_attention_tick.ogg`
- Project use: synchronized tutorial attention peaks for navigation buttons and newly revealed choices
- Processing: extracted 00:00.055-00:00.678 as one notification, removed head/tail silence, and applied 10 ms fades. Runtime code plays this one-shot at the first three visual peaks; the file is not pre-repeated.

## Call-ended busy signal

- Name: Telephone - Dial and call - Busy signal
- Creator: ShidenBeatsMusic (confirmed from the Pixabay page's structured `AudioObject.creator` data)
- Source: Pixabay
- Asset page: https://pixabay.com/sound-effects/technology-telephone-dial-and-call-busy-signal-21152/
- License: Pixabay Content License
- Download date: 2026-07-20
- Original project file: `assets/audio/source/pixabay_telephone_busy_signal_21152.mp3`
- Original SHA-256: `40598EA289DACB112BE309381C6B15A27D6FA32E9E296894496EBB6EBBDC0653`
- Runtime project file: `assets/audio/ui/phone/call_ended_busy_three.ogg`
- Project use: three-tone call-ended presentation
- Processing: extracted only 00:04.995-00:07.548, containing the first three consecutive complete busy tones and their original intervals, with 15 ms fades. Dial tones, keypad tones, and the fourth and later busy tones are excluded.
