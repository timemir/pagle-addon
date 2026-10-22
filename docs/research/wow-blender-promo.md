# Pagle promotional animation: WoW assets in Blender

Researched 2026-10-18. Primary sources: exporter source code, project release notes and Blender documentation. This is a production recommendation; no WoW model export or imported animation has been tested locally yet.

## Recommendation

Use **wow.export → GLB/glTF for animated characters**, and **wow.export → OBJ plus its Blender importer for the environment**. Build a small fishing scene before attempting a full trailer. Keep the character, shore, fishing props, camera and graphic overlays separate so each can be revised independently.

The maintained upstream is [Kruithne/wow.export](https://github.com/Kruithne/wow.export); download through its [official project site](https://www.kruithne.net/wow.export/). Search results also point to [Marlamin's repository](https://github.com/Marlamin/wow.export), but that copy was archived on 2026-04-24. Its GitHub release page is not the right place to select a current download.

## What the tools actually support

| Route | Verified capability | Consequence for Pagle |
|---|---|---|
| wow.export | Local Retail/Classic clients, online CDN streaming, legacy MPQ browsing, models, terrain and Blender importer. | One tool can supply both the angler and a recognizable shoreline. [Project README](https://github.com/Kruithne/wow.export#readme) |
| Animated character export | Modern M2 exporter loads skeletons and external animation files, writes glTF/GLB, and includes equipment with bone data. | Export the dressed character with **Export Animations** enabled. Source proves a pipeline exists; exact race/gear correctness still needs testing. [M2 exporter](https://github.com/Kruithne/wow.export/blob/main/src/js/3D/exporters/M2Exporter.js) |
| Equipment animation | glTF writer supports skin weights for equipment and bone attachments for rigid equipment. | Armor and a held pole have a route to follow the character; verify the selected fishing pole and grip. [glTF writer](https://github.com/Kruithne/wow.export/blob/main/src/js/3D/writers/GLTFWriter.js) |
| Fishing clips | Animation names include `FishingCast` and `FishingLoop`. | Start with these clips; their presence in the mapping does not guarantee every selected model contains them. [Animation mapping](https://github.com/Kruithne/wow.export/blob/main/src/js/3D/AnimMapper.js) |
| Blender importer | Current wow.export add-on declares Blender 5.0, invokes Blender's built-in glTF importer, and exposes terrain blending, object placement, liquids and UV animation controls for OBJ imports. | A credible route for Blender 5.2; the version declaration is not proof of a successful 5.2 import. [Add-on source](https://github.com/Kruithne/wow.export/blob/main/addons/blender/io_scene_wowobj/__init__.py) |

Version evidence: the active upstream changelog's newest entry inspected is **0.2.19, 2026-06-22**. Relevant earlier changes include equipment export and Classic character imports (0.2.7), grip posing (0.2.9), NPC export (0.2.14), and legacy MPQ terrain export plus extended character customization (0.2.18). It also records Wowhead Dressing Room URL import. These are features of those versions and later, rather than a guarantee that every beta asset works. [Current changelog](https://github.com/Kruithne/wow.export/blob/main/CHANGELOG.md)

**Legacy clients are a separate case.** Classic Era/Classic beta installed through Battle.net use modern client storage. A historical 1.x/2.x/3.x MPQ installation follows a different exporter: the inspected legacy M2 exporter implements OBJ/STL, with no glTF method. Do not assume animated character export from an old MPQ client merely because modern Classic supports it. [Legacy M2 exporter](https://github.com/Kruithne/wow.export/blob/main/src/js/3D/exporters/M2LegacyExporter.js)

## Local starting point

Read-only inspection in this session established:

- Blender responds through its active MCP server and reports **5.2.2 LTS**. Its glTF import operator is available. The current file is unsaved and contains the default Cube, Light and Camera.
- The installation root is **`G:/World of Warcraft`**, containing `Data` and `.build.info`. Product directories include `_classic_beta_`, `_classic_era_`, `_classic_`, `_retail_` and `_beta_`.
- The active `wow_classic_beta` entry in `.build.info` reports **1.60.1.70450**. The repo's [DB2 build pin](../../data/db2/build.toml) is older, **1.60.1.70338**; it is not evidence of the installed build.

For the first extraction, point wow.export at the installation root and select the **Classic beta product matching Pagle**, rather than selecting Retail by habit. If that beta product is unsupported, use an appropriate Classic Era client for visual assets and record the substitution. An online CDN source is another documented option, but first use the available local installation.

## First production test

1. **Create one angler.** Select the intended race/body and appearance, equip simple fishing clothes and one pole, and save the character configuration. Prefer manual customization or a Dressing Room import when a Classic character lookup is unavailable. Pick the Classic appearance deliberately; Retail HD models may change the intended aesthetic.
2. **Export GLB with textures and animations.** GLB is convenient for keeping a character's mesh and textures together. Keep the original export and record the exporter version, client product/build, character settings and item IDs.
3. **Import with Blender's glTF importer.** Inspect skin, hair, eyes, alpha textures, gear and pole first. Find the fishing actions in the NLA editor and scrub them. Blender documents that imported glTF clips become actions/NLA tracks, with the first playing initially; use the track Solo control or animation switcher to inspect others. [Blender glTF documentation](https://docs.blender.org/manual/en/5.1/addons/import_export/scene_gltf2.html)
4. **Bring in one small shoreline.** Export only the terrain tile(s), dock, trees and buildings visible to the planned camera, retaining metadata and textures. Use wow.export's WoW OBJ importer for placement/material reconstruction. Avoid exporting an entire zone before the shot is established.
5. **Make the shot work in Blender.** Add the water surface, fishing line, bobber, ripple and catch splash as needed. Treat these as authored effects until the asset test proves any imported equivalents sufficient. Use a short camera move and one cast/idle sequence before investing in additional shots.
6. **Render a 3–5 second preview.** Acceptance: readable character, correct gear attachment throughout the clip, no missing textures, acceptable foliage edges, convincing water, and a clean handoff from cast to fishing idle. Only then schedule the final animation and render.

Imported game assets supply geometry, textures and animation data; they do not establish a complete cinematic lighting, water or effect setup. Budget for material cleanup and targeted animation corrections. Preserve the imported deform skeleton for existing clips; add animation controls only if the shot requires custom acting.

## Alternatives and why they are secondary

**WoW Model Viewer:** the current README describes modern Retail/Classic viewing and OBJ export, but says **FBX export and its Blender add-on installer are absent from the current 1.1 release**. Source builds can optionally enable the FBX exporter with the Autodesk SDK. Armory import is Retail-only, and historical MPQ models cannot appear in its viewport. Older FBX tutorials therefore do not establish what the current downloadable build can do. Useful for asset inspection or static props; less direct for this animated Blender pipeline. [Maintainer README](https://github.com/wowmodelviewer/wowmodelviewer#readme)

**WoW Blender Studio:** a native WoW format editing environment. The upstream release page explicitly labels its download for **Blender 3.4**, and its tags still use that prefix, including experimental 1.1.0. No verified Blender 5.2 support was found. Consider a separate compatible Blender installation only if native M2/WMO editing becomes necessary; do not make it a dependency of the first promo shot. [Upstream release](https://gitlab.com/skarnproject/blender-wow-studio/-/releases/3.4-1.0), [tags](https://gitlab.com/skarnproject/blender-wow-studio/-/tags)

The older [Blender WMO importer repository](https://github.com/WowDevTools/Blender-WMO-import-export-scripts) is deprecated, limited to Blender 2.79b, and explicitly directs users to WoW Blender Studio. It is unsuitable for the running Blender version.

## Remaining unknowns

- Whether wow.export's downloadable build recognizes the exact installed Classic beta product/build and its customization tables.
- Whether the selected angler's fishing clips export and play correctly, including the chosen pole, grip and any armor attachments.
- Whether the desired map region and its material metadata import cleanly in Blender 5.2.2.
- Which scene/location, character, duration and final frame format will be chosen. The short proof above is intentionally useful before those decisions are fixed.

## Proposed Pagle promo treatment

Creative recommendation, rather than an upstream tool capability: make a **30–40 second fishing vignette**, with the cinematic world leading into the actual addon. The tangible leather, parchment, brass and wax described in the [store listing draft](../store/listing.md) give the film a consistent visual language. A working line is **“Pagle. Every catch has a story.”** This is a proposed tagline, not existing approved copy.

| Time | Picture | Message |
|---|---|---|
| 0–6 s | Early light on a familiar shoreline; close-up of the pole, line and bobber. | Establish the pleasure of fishing. |
| 6–13 s | The angler reels in; cut from the Catch to ink appearing on a Journal page. | Your Catches become a lasting collection. |
| 13–23 s | Actual Fish Journal footage: Species discovery, Angler Level, stars and Zone Mastery. | Progress beyond profession skill. |
| 23–31 s | A second angler joins the dock; a quick cut to Hunts or the Tackle Board. | More reasons to return to the water. |
| 31–40 s | Wide shoreline shot, Pagle title and a short call to action. | End on the addon name and the fishing mood. |

Use in-game capture of the real UI where possible, composited over or cut into the Blender footage. A physical 3D book can provide a transition into the Fish Journal, but its readable pages should use captured artwork/UI. The browser [Fish Journal prototype](../../prototypes/fish-journal/index.html) can help plan framing; verify final feature demonstrations against the actual addon.

The user's broader vision includes social features. The current [1.0 scope](../spec/README.md#outside-this-spec) puts social and guild features outside the release, so anglers together can convey community without inventing a leaderboard, friend sync or other shipping functionality. Revisit that distinction if this film is intended to announce a later release.

For a first proof, use **one dressed angler, one pole, a dock or shore, one bobber, one camera and one fishing clip**. Render a 3–5 second preview at modest resolution. After that works, settle the hero character, location, film length and delivery format, then assemble the longer edit. Render final shots as image sequences so an interrupted render can resume, and assemble the soundtrack and UI inserts afterward.

## Blender connection for subsequent production

The installed extension is **Blender Lab MCP 1.0.3**, whose manifest links to the [Blender Lab MCP page](https://www.blender.org/lab/mcp-server/). Its locally inspected implementation lives at `%APPDATA%/Blender Foundation/Blender/5.2/extensions/lab_blender_org/mcp/mcp_to_blender_server.py`.

It expects a UTF-8 JSON request terminated by a null byte, with `type: "execute"`, a `code` string and the boolean `strict_json: true`. Executed Python returns data by assigning a dictionary to `result`. A read-only `bpy` query using that protocol succeeded on `127.0.0.1:9876`. The earlier `get_scene_info` probe used a different add-on's protocol and timed out; it did not establish a fault in this server.

This gives us a working path to automate imports, camera moves, lighting, keyframes and preview rendering in the running Blender once assets are available. No scene objects were changed during this research.

## Publication note

Blizzard's [Video Policy](https://www.blizzard.com/en-us/legal/dd76b654-f2c4-4aaa-ba49-ca3122de2376/blizzard-video-policy) describes community video use subject to its conditions, including restrictions on commercial use. Treat it as the publication reference for a video using WoW assets; exporting a model does not itself grant rights to those assets. Keep extracted game files in the production workspace, separate from the addon's distributed package. Policy summaries were visible in Blizzard's indexed page; direct retrieval returned HTTP 403 during this research.
