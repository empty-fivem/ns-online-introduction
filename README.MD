GTA:Online Introduction (not only the cutscene everyone knows, but also the scripted part)

Videos:
  - Male: no
  - Female: no

Fixed bugs:
  - ✅ Lamar doesn't speak when you're in the car with him — the conversation was built with the wrong ADD_LINE_TO_CONVERSATION arguments. Each line's audio filename, speaker/listener and flags are now read from the FM_1AU GXT block exactly like the game's dialogue_handler, the conversation is started once and left to play out (instead of being recreated every frame), and MP audio data is mounted with SetAudioFlag("LoadMPData", true).
  - ✅ Subtitles don't work — the game's subtitle labels use the "~z~" token that the HUD only shows when the profile Subtitles setting is on. They are now printed manually so they always show: drive lines are drawn as each conversation line goes on air, and the arrival cutscene lines are re-fired from GetCutsceneTime() (FiveM doesn't play the cutfile's own subtitle events).
  - ✅ Female intro shows the wrong gender — the plane cutscene re-detected gender from the live ped instead of the chosen variant, and the scripted scenes (drive/garage/race) always render the live ped, so forcing female on a male ped fell back to male. Fixed by giving the cutscene the director's isMale, and, when the forced gender differs from the ped, temporarily swapping to a default freemode ped of that gender (original model + appearance saved to a hidden clone and restored via ClonePedToTarget when the intro ends). No swap happens when the ped already matches.
  - ✅ Lamar's mouth stays closed while he talks in the car — a ped driven by a synchronized scene has viseme (lip-sync) anims disabled, so the body animated but the face never moved. Fixed by calling SetPedCanPlayVisemeAnims(ped, true, false) on the speaking ped for each line, and by registering the Lamar ped that is actually on screen (the drive swaps between an in-game and a cutscene ped) so the lip-sync lands on the visible one.
  - ✅ Rendering issues in the car scene — not a script bug. This is just how the RAGE engine streams during a fast scripted drive. The streaming setup already matches the original game (SRL pre-streaming path, readahead times, focus handling), so there's nothing to fix. (Could also be my computer is trash...)

Known bugs:
  - Missing scene — Reference: https://youtu.be/KF2jp5ic4LY?t=241 ("GTA Online - Welcome to Los Santos", ~4:01).

Added:
  - ✅ Display help text — the tutorial help boxes (FMIC_INTRO2 / FMIC_RACE1 / FMIC_RACE2 / FMIC_GAR / FMIC_TENN) now show during the intro. Fired via Util.printHelp (BeginTextCommandDisplayHelp) at each phase in the original's order — anchored to the SRL readahead changes from fm_intro.c. The FMINT text block is loaded early in setup so the labels resolve in time.

Credits:
  - Original script: Space V (not-a-script) — not-a-script/ns-online-introduction
  - References used for the fixes:
    - Decompiled fm_intro.c / fm_intro_cut_dev.c — calamity-inc/GTA-V-Decompiled-Scripts
    - Decompiled dialogue_handler.c — calamity-inc/GTA-V-Decompiled-Scripts
    - FM_1AU text label dump — RocwoDev/GTA-V-All-Labels
    - Claude for the reverse engineering

:warning: This script is not plug & play. If you don't have knowledge in development/FiveM, don't use it
