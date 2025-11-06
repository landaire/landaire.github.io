+++
title = "A File Format Uncracked for 20 Years"
description = "\"I’ve had enough reasonable file formats fired at me in my time to tell you that wasn’t one\" - Sam Fisher"
summary = "\"I’ve had enough reasonable file formats fired at me in my time to tell you that wasn’t one\" - Sam Fisher"
template = "toc_page.html"
toc = true
date = "2025-11-06"

[extra]
image = "/img/splinter-cell/banner.png"
image_width = 360
image_height = 240
+++

[Splinter Cell (2002)](<https://en.wikipedia.org/wiki/Tom_Clancy%27s_Splinter_Cell_(video_game)>) was one of the first games I had on the original Xbox and still remains one of my favorite games of all time. The game was developed by Ubisoft using Unreal Engine 2 -- licensed from a small indie dev called Epic Games who continues to use and license its game engine technology for contemporary small-budget indie games such as _Fortnite_ and _Halo: Campaign Evolved_.

I got into programming/hacking through video games and I still enjoy data mining/exploring cut content from the few games I play nowadays. I recently randomly decided to look online for cut content from Splinter Cell and I was kind of surprised by the lack of datamined info. There isn't really much information on the topic aside from [an OG Xbox review copy](<https://hiddenpalace.org/Tom_Clancy%27s_Splinter_Cell_(Sep_13,_2002_prototype)>) of the game which contained two levels cut from the retail Xbox version and some other minor differences.

Naturally, I decided to _legally backup my personal disc copy of the game_ and got to digging into the files.

My initial objective was to examine the format of the game data and sniff out if there's any indicators of cut content such as textures, models, interesting strings -- whatever. Some nice finds would be debug menus, voice lines, weapon concepts, or levels that are unreachable through normal game progression.

The game's (truncated) file tree looks like this:

```
.
├── contentimage.xbx
├── dashupdate.xbe
├── default.xbe
├── downloader.xbe
├── dynamicxbox.umd
├── LMaps
│   ├── 000_menu
│   │   ├── common.lin
│   │   └── menu.lin
│   ├── 001_Training
│   │   ├── 0_0_2_Training.bik
│   │   ├── 0_0_2_Training.lin
│   │   ├── 0_0_2_Training_progress.tga
│   │   ├── 0_0_2_Training_start.tga
│   │   ├── 0_0_3_Training.lin
│   │   ├── 0_0_3_Training_complete.tga
│   │   ├── 0_0_3_Training_progress.tga
│   │   ├── common.lin
│   │   └── French
│   │       ├── 0_0_2_Training_progress.tga
│   │       ├── 0_0_2_Training_start.tga
│   │       ├── 0_0_3_Training_complete.tga
│   │       └── 0_0_3_Training_progress.tga
```

`.xbe` files are Xbox Executables, `.bik` are [Bink Video](https://www.radgametools.com/bnkmain.htm) files, and `.tga` are images... but `.lin` is new to me.

In Splinter Cell the maps are divided into separate parts. So in the training mission `001_Training`, you likely have `0_0_2_Training.lin` for the first part and `0_0_3_Training.lin` for the second which gets loaded via an in-game loading sequence after advancing to some zone in the map.

I instantly thought that `common.lin` might contain data common to both of these parts as a way to reduce file size. The Halo games for instance have a `shared.map` containing assets which are shared across most maps, and load data at a fixed address so that the file can be trivially transmuted from a binary blob to its in-memory data structures.

Examining the `common.lin` file in a hex editor, a few things become immediately apparent:

```
┌────────┬─────────────────────────┬─────────────────────────┬────────┬────────┐
│00000000│ 04 00 00 00 0c 00 00 00 ┊ 78 9c 7b d7 97 c2 00 00 │........┊x.{.....│
│00000010│ 06 2e 01 e1 04 00 00 00 ┊ 0c 00 00 00 78 9c 63 60 │........┊....x.c`│
│00000020│ 90 66 00 00 00 3a 00 1c ┊ 04 00 00 00 0c 00 00 00 │.f...:..┊........│
│00000030│ 78 9c 73 48 67 60 00 00 ┊ 02 39 00 a8 04 00 00 00 │x.sHg`..┊.9......│
│00000040│ 0c 00 00 00 78 9c b3 e0 ┊ 65 60 00 00 01 0b 00 46 │....x...┊e`.....F│
└────────┴─────────────────────────┴─────────────────────────┴────────┴────────┘
```

- Data between `0x0..0x4` and `0x4..0x8` are little-endian 32-bit integers: `0x00000004` and `0x0000000C`.
- At offset `0x8` is what appears to be a zlib-compressed chunk of data -- denoted by the 'x' in the ASCII view and `0x78 0x9c` in the hex view.
- There's another sequence of this at offset `0x14`, which happens to be `0xC` bytes past the offset of the zlib data (`0x8`), and another at `0x28`.

Presumably the format here is `{decompressed_data_len, compressed_data_len, zlib_block[compressed_data_len]}` repeated.

So far so good.

I wrote a quick tool to decompress the archive and without a hitch ended up with a 64k file containing 4 `u32`s prefixing it. Since these 4 are in their own dedicated zlib-compressed chunks I consider to be separate from the main data. I later reverse engineered and identified how they are used:

```
uncompressed_data_size: 0x648EEE
texture_cache_size? - later used when calling D3DDevice_CreateTexture2: 0x1B0000
vertex_buffer_size? - ditto, D3DDevice_CreateVertexBuffer2: 0x6740
index_buffer_size? - ditto, XGSetIndexBufferHeader: 0xD38
```

And this is what the main data section's first 0x100 bytes look like:

```
┌────────┬─────────────────────────┬─────────────────────────┬────────┬────────┐
│00000000│ 5c 58 9e 13 00 a3 c5 e3 ┊ 9f b4 92 9b 13 5c 58 9e │\X......┊.....\X.│
│00000010│ 13 01 00 00 00 04 2a d6 ┊ fe 7e 37 13 4d 61 70 73 │......*.┊.~7.Maps│
│00000020│ 5c 6d 65 6e 75 5c 6d 65 ┊ 6e 75 2e 75 6e 72 00 00 │\menu\me┊nu.unr..│
│00000030│ 00 00 00 ee de 00 00 00 ┊ 00 00 00 16 4d 61 70 73 │........┊....Maps│
│00000040│ 5c 31 5f 31 5f 30 54 62 ┊ 69 6c 69 73 69 2e 75 6e │\1_1_0Tb┊ilisi.un│
│00000050│ 72 00 f0 de 00 00 6d c9 ┊ 17 00 00 00 00 00 16 4d │r.....m.┊.......M│
│00000060│ 61 70 73 5c 31 5f 31 5f ┊ 31 54 62 69 6c 69 73 69 │aps\1_1_┊1Tbilisi│
│00000070│ 2e 75 6e 72 00 60 a8 18 ┊ 00 98 34 21 00 00 00 00 │.unr.`..┊..4!....│
│00000080│ 00 16 4d 61 70 73 5c 31 ┊ 5f 31 5f 32 54 62 69 6c │..Maps\1┊_1_2Tbil│
│00000090│ 69 73 69 2e 75 6e 72 00 ┊ 00 dd 39 00 89 63 19 00 │isi.unr.┊..9..c..│
│000000a0│ 00 00 00 00 18 4d 61 70 ┊ 73 5c 30 5f 30 5f 32 5f │.....Map┊s\0_0_2_│
│000000b0│ 54 72 61 69 6e 69 6e 67 ┊ 2e 75 6e 72 00 90 40 53 │Training┊.unr..@S│
│000000c0│ 00 0f 9f 0c 00 00 00 00 ┊ 00 18 4d 61 70 73 5c 30 │........┊..Maps\0│
│000000d0│ 5f 30 5f 33 5f 54 72 61 ┊ 69 6e 69 6e 67 2e 75 6e │_0_3_Tra┊ining.un│
│000000e0│ 72 00 a0 df 5f 00 48 86 ┊ 11 00 00 00 00 00 1e 4d │r..._.H.┊.......M│
│000000f0│ 61 70 73 5c 31 5f 32 5f ┊ 31 44 65 66 65 6e 73 65 │aps\1_2_┊1Defense│
└────────┴─────────────────────────┴─────────────────────────┴────────┴────────┘
```

And at what appears to be the end of the file table:

```
┌────────┬─────────────────────────┬─────────────────────────┬────────┬────────┐
│0002c580│ 79 6e 63 68 5c 69 6e 74 ┊ 5c 55 73 61 53 6f 6c 64 │ynch\int┊\UsaSold│
│0002c590│ 69 65 72 5c 55 53 4f 55 ┊ 4e 43 5f 33 2e 62 69 6e │ier\USOU┊NC_3.bin│
│0002c5a0│ 00 40 8d 9b 13 74 05 00 ┊ 00 00 00 00 00 c1 83 2a │.@...t..┊.......*│
│0002c5b0│ 9e 64 00 11 00 01 00 00 ┊ 00 10 0e 00 00 88 00 00 │.d......┊........│
│0002c5c0│ 00 fa 0f 00 00 f3 7a 11 ┊ 00 4e 00 00 00 3e 78 11 │......z.┊.N...>x.│
│0002c5d0│ 00 de ad f0 0f 42 01 9c ┊ 90 92 8f 96 93 9e 8b 96 │.....B..┊........│
│0002c5e0│ 90 91 9a 9c 97 9a 93 90 ┊ 91 df af bc ba bc b7 ba │........┊........│
│0002c5f0│ b3 b0 b1 df a6 c5 a3 ba ┊ bc b7 ba b3 b0 b1 a3 ac │........┊........│
│0002c600│ a6 ac ab ba b2 a3 df ce ┊ cf d0 cd c9 d0 cf cd df │........┊........│
│0002c610│ cd ce c5 cf cd c5 ce cb ┊ ff 00 00 00 00 00 00 00 │........┊........│
│0002c620│ 00 00 00 00 00 00 00 00 ┊ 00 01 00 00 00 fa 0f 00 │........┊........│
│0002c630│ 00 10 0e 00 00 05 4e 6f ┊ 6e 65 00 10 04 07 04 06 │......No┊ne......│
│0002c640│ 43 6f 6c 6f 72 00 10 04 ┊ 07 04 0d 49 6e 74 65 72 │Color...┊...Inter│
│0002c650│ 6e 61 6c 54 69 6d 65 00 ┊ 10 00 07 00 07 45 6e 67 │nalTime.┊.....Eng│
│0002c660│ 69 6e 65 00 10 00 07 04 ┊ 05 43 6f 72 65 00 10 00 │ine.....┊.Core...│
│0002c670│ 07 04 07 53 79 73 74 65 ┊ 6d 00 10 00 07 04 06 55 │...Syste┊m......U│
└────────┴─────────────────────────┴─────────────────────────┴────────┴────────┘
```

Just to save some blog space on my trial and error process here, I'm going to drop some of the resources I found which discuss this format:

- [https://oldunreal.com/phpBB3/viewtopic.php?t=4885](https://oldunreal.com/phpBB3/viewtopic.php?t=4885)
- [https://zenhax.com/viewtopic.php@t=1049.html](https://zenhax.com/viewtopic.php@t=1049.html)
- [https://reshax.com/topic/1421-ubisoft-unreal-engine-2-open-season-2006-video-game-umd-also-lin-xbox-xbox-360-pc-and-liv-latter-being-exclusive-to-xbox-360/](https://reshax.com/topic/1421-ubisoft-unreal-engine-2-open-season-2006-video-game-umd-also-lin-xbox-xbox-360-pc-and-liv-latter-being-exclusive-to-xbox-360/)
- [https://www.unrealarchive.org/wikis/unreal-wiki/Legacy:UMOD/File_Format.html](https://www.unrealarchive.org/wikis/unreal-wiki/Legacy:UMOD/File_Format.html)

The last two posts in particular had structure info that was helpful in figuring out the packed int format (think UTF-8 and its variable-length encoding) and a couple unknown vars.

What I gathered from all of these posts was that over time, nobody's really been able to figure out this format's quirks sufficiently to unpack the data. Everyone seems to think that some kind of VFS is created and the data gets mapped at a specific address and then read. Which may be true for some titles or consoles, but is not really the case for this one.

**My objective has now changed:** I now want to reverse engineer this file format and be able to dump individual files from this filesystem. Then I can achieve my core goal of looking for cut content. Then I can maybe play the game.

## tl;dr of the general `.lin` structure

`common.lin` has a different layout from the other `.lin` files that looks roughly like:

```rust
/* ==== Standard Data ==== */

// These three, from research + reverse engineering, should not be considered
// as part of the "whole" file
u32             maybe_load_address; // 5C 58 9E 13 (0x139e585c) in common.lin
compressed_int  name_length;        // 0 in common.lin
char            name[name_length];

/* ==== common.lin-specific file header ==== */

u32             magic;              // 0x9fe3c5a3 in little endian, i.e. A3 C5 E3 9F

u32             unk_address;        // B4 92 9B 13, (0x139b92b4) suspiciously similar to maybe_load_address.
                                    // unk_address - load_address gives you the start of the file
                                    // table, relative to the magic?
u32             load_address2;      // 5C 58 9E 13 same as maybe_load_address

u8              unknown[8];         // 01 00 00 00 04 2A D6 FE
compressed_int  file_entry_count;

FileEntry       file_entries[file_entry_count];

struct FileEntry {
    compressed_int  name_len;
    char            name[name_len];
    u32             offset;
    u32             len;
    u32             unk;
}
```

Then immediately following the `FileEntry` table are 54 Unreal Engine Package files in sequence (identified via their `0x9E2A83C1` magic -- these are also referred to as **Linker** files) that presumably map to the files in the file table.

The map-specific files like `menu.lin` and `0_0_2_Training.lin` do not have the file table, but they do have the first 3 fields (and a non-null string like "menu\x0" for the name field) then a sequence of Linker files.

But the difficulty with parsing this data starts with the file table.

## Problems

### File Table

The file table is a very simple format that I'm able to parse with my program:

```rust
FileEntry {
    name: Maps\\menu\\menu.unr,
    offset: 0x0,
    len: 0xDEEE,
    unk: 0x0,
},
FileEntry {
    name: Maps\\1_1_0Tbilisi.unr,
    offset: 0xDEF0,
    len: 0x17C96D,
    unk: 0x0,
},
FileEntry {
    name: Maps\\1_1_1Tbilisi.unr,
    offset: 0x18A860,
    len: 0x213498,
    unk: 0x0,
},
FileEntry {
    name: Maps\\1_1_2Tbilisi.unr,
    offset: 0x39DD00,
    len: 0x196389,
    unk: 0x0,
},
FileEntry {
    name: Maps\\0_0_2_Training.unr,
    offset: 0x534090,
    len: 0xC9F0F,
    unk: 0x0,
},
FileEntry {
    name: Maps\\0_0_3_Training.unr,
    offset: 0x5FDFA0,
    len: 0x118648,
    unk: 0x0,
},
FileEntry {
    name: Maps\\1_2_1DefenseMinistry.unr,
    offset: 0x7165F0,
    len: 0x249AF6,
    unk: 0x0,
},
FileEntry {
    name: Maps\\1_2_2DefenseMinistry.unr,
    offset: 0x9600F0,
    len: 0x20F662,
    unk: 0x0,
},
<snip>
```

At first glance the files seem to be laid out sequentially, aligned to a pointer-width boundary. Except, notice that last file's offset... `0x9600F0`. This is way outside of the range of my `0x648EEE`-length file, and this file list contains 3,582 files! Not 54 as expected from the count of Unreal Package magics!

The mismatch file count could be explained by not every file in this container being an Unreal Package, but the offsets so far are _extremely_ wrong.

### File Reading

After debugging the game in the Original Xbox emulator [xemu](https://xemu.app/), I was able to find the routine which opens the file, as well as the function which reads and decompresses data.

{% collapse(preview="Function Identification Methodology") %}

If anyone's curious on the methodology: I identified `NtCreateFile`, set a breakpoint, recorded the `HANDLE` returned for the file path I cared about, then set a breakpoint at `NtReadFile` and broke when the input `HANDLE` matched the expected value. The call stack/stepping from here helped identify interesting callers. Alternatively, the string "`unknown compression method`" is useful in finding the decompression routine `inflateInit2`.

This is not super relevant to the blog post which is why it's in this little collapse section. I hate reading posts like this that skip over a detail I'm interested in like it's just common knowledge how something is done, so I'm trying to avoid doing that :)

{% end %}

_Note: Click images to see in higher res_.

[![Compressed read function high-level IL](/img/splinter-cell/compressed_fn_hlil.png)](/img/splinter-cell/compressed_fn_hlil.png)

This function basically checks the requested read size against how much data it has precached in its decompressed data buffer. It will then copy as much data as it can from its precached buffer to the output buffer, then read the next block of compressed zlib data into its precache buffer if the previous one was exhausted. Repeat this process until the request is satisfied.

Identifying this function was pretty important for my reverse engineering process. I could now set breakpoints on the code which copies data to the output buffer and see who's calling this function when data is read from offsets I care about.

I stepped through this code, set Memory Read breakpoints on data I didn't yet understand, and noted something interesting early on!

Those "addresses" from the header (`0x139e585c`)? Those are actually passed to what I can only guess is a `Seek` routine which updates the `position` property of the file reader, which then makes an indirect call to another function that **literally does nothing**.

The entire content of the function is:

```
retn    4
```

That's it.

Then the reads just... continue from their last position? Since the function is an indirect call, I can only assume that I was looking at some composed C++ object where the outer class object updates its own `position` in `Seek()` and then calls its underlying file reader's `Seek()`... which is a no-op?

After setting Memory Read breakpoints on the object's `position` field, I noticed it's only ever used in their file reader equivalent of `FTell()`. It doesn't affect where data is actually being read from at all.

The reason for the `Seek()` being a no-op is likely because the underlying file reader is reading directly from the compressed buffer, which reads in `0x4000`-byte chunks. Since you cannot reasonably map an uncompressed data offset to a compressed offset the format must be designed to ignore seeks and just read data linearly.

...the `.lin` extension makes a lot more sense.

💡 In order to read these files, you have to assume that you cannot seek forward/backward. Easy enough.

### Load Order Matters

We still have a problem that has not been addressed: why does the file table have a large count of files with bad offsets?

I continued to use breakpoints inside of the file read function to trace where interesting bits of data were read and forced a break when the data immediately following the file table was read. Eventually I traced the file read operation back far enough to find this function, `StaticLoadObject`:

[![StaticLoadObject implementation](/img/splinter-cell/static_load_object.png)](/img/splinter-cell/static_load_object.png)

This function calls `ResolveName` which I was able to log the arguments to via a debugger breakpoint script, which told me the `InName` was `ini:Engine.Engine.GameEngine`:

[![ResolveName implementation](/img/splinter-cell/resolve_name.png)](/img/splinter-cell/resolve_name.png)

This `ini:Engine.Engine.GameEngine` name gets parsed as:

- `ini:` <- resolve the name from the game's INI files
- `Engine.Engine` <- the INI table to read from
- `GameEngine` <- the key from the table to read

If I look in `UW.ini` included with the game, this table is defined as:

```ini
[Engine.Engine]
RenderDevice=D3DDrv.D3DRenderDevice
GameRenderDevice=D3DDrv.D3DRenderDevice
AudioDevice=XboxAudio.XboxAudioSubsystem
Console=Engine.Console
DefaultPlayerMenu=UPreview.UPreviewRootWindow
Language=int
GameEngine=Engine.GameEngine
EditorEngine=Editor.EditorEngine
WindowedRenderDevice=D3DDrv.D3DRenderDevice
DefaultGame=Echelon.EchelonGameInfo
DefaultServerGame=WarfareGame.WarfareTeamGame
ViewportManager=XboxDrv.XboxClient
Render=Render.Render
Input=Engine.Input
Canvas=Echelon.ECanvas
Editor3DRenderDevice=D3DDrv.D3DRenderDevice
```

So the resulting value returned from this function is `Engine.GameEngine`, which matches what this function resolves.

This is then used to resolve the **package** `Engine` and its **exported object** `GameEngine`. The game binary looks for the file `Engine` in its available sources (partial matching strategy), which includes searching against the LIN file table, and then resolves that name as `System\Engine.u`. My tool that reads the file table confirms that this is declared in the LIN file:

```rust
FileEntry {
    name: System\\Engine.u,
    offset: 0x13482120,
    len: 0x127DA1,
    unk: 0x0,
},
```

Except the file start offset + len don't make sense. If I assume the `Engine.u` file is the first file immediately following the file table, advancing forward by this length appears to land right in the middle of some string?

```
┌────────┬─────────────────────────┬─────────────────────────┬────────┬────────┐
│00154330│ 09 45 4d 65 73 68 53 46 ┊ 58 00 10 00 07 00 1b 43 │.EMeshSF┊X......C│
│00154340│ 68 61 6e 64 65 72 6c 65 ┊ 72 43 72 79 73 74 61 6c │handerle┊rCrystal│
│00154350│ 50 61 72 74 69 63 75 6c ┊ 65 00 10 00 07 00 12 46 │Particul┊e......F│
└────────┴─────────────────────────┴─────────────────────────┴────────┴────────┘
```

I'll save some time and just say that I did not identify the wrong file. The lengths just don't matter, and for all intents and purposes are wrong. The reader in the game engine must just read the data in-order using its self-description in its own header?

The Unreal Engine Package/Linker file format has been [well documented](https://eliotvu.com/page/unreal-package-file-format) and does include some sizes in its header. The packages contain about what you'd expect of some object-oriented programming (OOP) script/data format.

It has _exported_ objects which are named instances of some OOP type and has properties and data. Or the object can be a class/struct definition. The exports may rely on types exported from other packages which are declared as _imports_. Both of these have names or string data associated with them which are defined in the _name_ table.

I mapped the existing documentation to the following Rust struct:

```rust
pub struct PackageHeader<'i> {
    pub version: u32,
    pub flags: u32,
    pub name_count: u32,
    pub name_offset: u32,
    pub export_count: u32,
    pub export_offset: u32,
    pub import_count: u32,
    pub import_offset: u32,

    // Note: this is not in the above documented description
    pub unk: u32,
    // Ditto.
    // Not shown: compressed int for length of this data at this position
    pub unknown_data: &'i [u8],

    pub guid_a: u32,
    pub guid_b: u32,
    pub guid_c: u32,
    pub guid_d: u32,
    // Not shown: compressed int for length of this data at this position.
    pub generations: Vec<GenerationInfo>,
}
```

And of course, the offsets in this format are also unusable (e.g. the `name_offset` lands you _after_ the start of the name table). But the counts look good:

```rust
PackageHeader {
    version: 0x110064,
    flags: 0x1,
    name_count: 0xE10,
    name_offset: 0x88,
    export_count: 0xFFA,
    export_offset: 0x117AF3,
    import_count: 0x4E,
    import_offset: 0x11783E,
    unk: 0xFF0ADDE,
    unknown_data: [
      ...
    ]
    guid_a: 0x0,
    guid_b: 0x0,
    guid_c: 0x0,
    guid_d: 0x0,
    generations: [
        GenerationInfo {
            export_count: 0xFFA,
            name_count: 0xE10,
        },
    ],
}
```

Now with my tool updated to read these tables -- parsing by assuming that they immediately follow this header and each other -- I have imports that look like:

```rust
Package Core.Core
Import { class_package: 4, class_name: B64, package_index: 0, object_name: 4, object: None }

Class Core.Object
Import { class_package: 4, class_name: B62, package_index: FFFFFFFF, object_name: 13, object: None }

Class Core.Function
Import { class_package: 4, class_name: B62, package_index: FFFFFFFF, object_name: BBD, object: None }
```

And exports:

```rust
Class Actor
(0x0) ObjectExport {
    class_index: 0x0,
    super_index: 0xFFFFFFFE,
    package_index: 0x0,
    object_name: 0x206,
    object_flags: 0x40F0004,
    serial_size: 0x3A8,
    serial_offset: 0xF719,
}

Class Pawn
(0x1) ObjectExport {
    class_index: 0x0,
    super_index: 0x1,
    package_index: 0x0,
    object_name: 0x1A,
    object_flags: 0x40F0004,
    serial_size: 0x281,
    serial_offset: 0xFAC1,
}

...

Class GameEngine
(0xEFB) ObjectExport {
    class_index: 0x0,
    super_index: 0x1C8,
    package_index: 0x0,
    object_name: 0x1D8,
    object_flags: 0x40F0004,
    serial_size: 0x5B,
    serial_offset: 0xC50DB,
}
```

So the `GameEngine` object has export index `0xEFB` and its data is supposedly located at offset `0xC50DB` relative to the package start. You guessed it though, its offset is wrong!

### Export Data

Up to this point we know:

1. You cannot seek in the file reader.
2. The offsets do not map cleanly to the on-disk representation and aren't really used other than for position tracking.
3. The sizes (at least in the file table, and I soon realized in the export data) are incorrect.
4. We know `GameEngine` is the first object requested by the C++ side of the game and is export index `0xEFB` in the `Engine` package. It may not be the first object actually _parsed_, but it's the first object requested.

Now, to achieve my goal of dumping these files I attempted to simply sum the size of these exports to figure out the end offset of the file... but trying a combination of that calculated size + any of the `{end_of_export_table, start_of_file}` offsets landed me in weird places with other Linker files in-between.

By referencing [Unreal-Library](https://github.com/EliotVU/Unreal-Library) to help fill in some of the blanks, I observed the following high-level parsing logic in the game engine:

1. An exported object is requested by the game. If it isn't loaded already, the export is lazy loaded.
2. Lazy loading requires resolving the `super` type's object. For some things this is the `Class` or `Struct` base types, for other things this is a different parent class which will eventually have `Class` as its parent type.
3. Exports have properties which can be of varying size. As you read an export, you deserialize its data as described by its `serial_size` and `serial_offset` fields, and however the types exported from the C++ side defines the deserialization routine.

Which visually results in something like the following flow when resolving imports/exports:

![Export parsing flow](/img/splinter-cell/export_load_flow_diagram.svg)

To give a concrete example, imagine that `GameEngine` has the following class hierarchy:

`GameEngine -> Engine -> Subsystem -> Class`

Also imagine that `GameEngine` is the very first object ever parsed -- nothing else has been loaded yet. Requesting to load `GameEngine` from the `Engine.u` package will trigger the following sequence of events:

1. `Engine.u` header read/parse (since no package has been created yet)
2. Lookup `Engine`'s `GameEngine` export. It's not yet parsed, so we need to construct this object by constructing/deserializing it.
3. `GameEngine`'s parent class is `Engine.Engine`. It has not yet been parsed, so we need to deserialize it **before** `GameEngine`.
4. `Core.Subsystem` is `Engine.Engine`'s parent class. Same thing.
5. `Core.u` header read/parse (since `Core` hasn't been loaded yet)
6. `Core.Class` is `Core.Subsystem`'s parent class (and the base class). Construct this object.
7. `Core.Class` property deserialization. We can now continue with `Core.Subsystem` creation.
8. `Core.Subsystem` property deserialization...
9. `Engine.Engine` property deserialization..
10. `Engine.GameEngine` property deserialization...
11. We can now return the fully constructed `Engine.GameEngine`.

I believe this can result in export data that is interleaved, unfortunately. For the above scenario the data may be on disk like the following diagram. **Note:** for space/simplicity I've omitted `Core.Class`, as well as the potential for the _properties themselves_ to trigger deserializing of other exports.

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                                                             │
│                        File Table                           │
│                                                             │
│                                                             │
│                                                             │
├───────────────────────────┬─────────────────────────────────┤
│Core.u Header              │ Engine.u Header                 │
│                           │                                 │
│                           │                                 │
├────┬────┬─────────────────┴───────┬─────────────────────────┤
│    │▰▰▰▰│▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰│                         │
│    │▰▰▰▰│▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰│          │    │         │
│    │▰▰▰▰│▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰│          │    │         │
│  ▲ │ ▲ ▰│▰▰ ▲ ▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰│        ▲ │   ▲│      ▲  │
├──┼─┴─┼──┴───┼─────────────────────┴────────┼─┴───┼┴──────┼──┤
│  │   │      │                              │     │       │  │
│  │   │    ┌─┴──────────────────────────┐   │     │       │  │
│  │   │    │ Core.Subsystem Export Data │   │     │       │  │
│  │   │    └────────────────────────────┘   │     │       │  │
│  │ ┌─┴────────────────────────────────┐    │     │       │  │
│  │ │ Engine (Super Class) Export Data │    │     │       │  │
│  │ └──────────────────────────────────┘    │     │       │  │
│  │                               ┌─────────┴─────┴───────┴──┤
│┌─┴────────────────────────┐      │    GameEngine Object     │
││ GameEngine Object Start  │      │        Properties        │
│└──────────────────────────┘      └──────────────────────────┤
└─────────────────────────────────────────────────────────────┘
```

And now if you imagine that there's a _second_ object which also extends from `Engine` loaded after `GameEngine`, then their common the super class `Engine` has already been parsed and its information is already in-memory. i.e. if you serialize two objects of the same exact type, the first object might have all the data for its parent classes interleaved with _its own_ export data and the second object only contains its own property data.

Unfortunately, this means that to read these files statically (even for just static recompilation) you need to have full knowledge of how each C++-implemented type is parsed in order to parse all exports and their properties. Additionally, reading one export may trigger resolving of imports in your own Linker object, which in turn trigger deserialization of exports in another Linker object.

This results in the export data's size not necessarily being _wrong_ per se, but not super usable without actually doing full parsing. If other exports are deserialized in the middle of deserializing an export, they will seek around and restore the original position. When the export is done deserializing it subtracts the post-deserialization `position` of the file reader from the saved pre-deserialization `position` and asserts that it equals the export's expected length. It's misleading though as can't simply read `SerialSize` bytes from its offset.

_Note: I'm not 100% confident in the data being interleaved vs just sequential. Through observing seek/read operations for various exports, I do see seeks going to a wildly different offset in the middle of deserializing an export, then another export deserializing, then seeking back to the original export and continuing to deserialize it again This is a PITA to debug though_.

### Why??????

I imagine there's a very good reason for packaging data this way. It's best to consider the constraints of the time:

1. The game is being shipped on a physical disc.
2. The Xbox has 64MB of RAM shared between the CPU and GPU, with some portion of that being dedicated to the OS.
3. The CPU wasn't terribly slow for the time, but wasting cycles would have been noticed.

The `.lin` format mitigates these issues with:

1. Compressing data means you save space on the disc... If you conveniently ignore the fact that `common.lin` is duplicated in each map's directory and is the same for every map I tested, which kinda negates part of this.
2. Streaming data in from the file instead of decompressing the whole thing at once saves on overall memory pressure during the data loading phase.
3. Laying out the file in a byte-for-byte exact read order increases I/O speeds by not having to seek around the physical media, and ensures that you don't need magic to translate an uncompressed offset to a compressed one in a performant manner.

## Logging Load Order for Static Recompilation

I really, really wanted to avoid doing any runtime dumping that requires playing the game in an emulator or physical console. It doesn't scale well to other games and is generally less flexible. But doing runtime observations are extremely useful in making sense of the format, so I went ahead and added some logging to get an idea of the file read order from the compressed archive when booting the game:

```
..\System\Engine.u
..\System\Core.u
..\System\Echelon.u
..\Textures\HUD.utx
..\Sounds\FisherFoley.uax
..\Sounds\CommonMusic.uax
..\System\EchelonEffect.u
..\Textures\ETexSFX.utx
..\Textures\2-1_CIA_tex.utx
..\Textures\generic_shaders.utx
..\Textures\LightGenTex.utx
..\Textures\5_1_PresidentialPalace_tex.utx
..\Textures\1_2_Def_Ministry_tex.utx
..\Textures\EGO_Tex.utx
..\Textures\ETexIngredient.utx
..\Textures\1-1_TBilisi_tex.utx
..\Textures\1_3_CaspianOilRefinery_TEX.utx
..\StaticMeshes\EMeshSFX.usx
..\StaticMeshes\EGO_OBJ.usx
..\Textures\ETexCharacter.utx
..\Textures\4_3_Chinese_Embassy_tex.utx
..\Textures\4_3_0_Chinese_Embassy_tex.utx
..\Textures\4_3_2_Chinese_Embassy_tex.utx
..\Sounds\water.uax
..\Sounds\DestroyableObjet.uax
..\Sounds\FisherVoice.uax
..\Sounds\FisherEquipement.uax
..\Sounds\GunCommon.uax
..\Sounds\Interface.uax
..\Sounds\Electronic.uax
..\Sounds\Dog.uax
..\Sounds\Lambert.uax
..\StaticMeshes\EMeshIngredient.usx
..\StaticMeshes\EMeshCharacter.usx
..\Textures\2_2_1_Kalinatek_tex.utx
..\StaticMeshes\LightGenOBJ.usx
..\Textures\ETexRenderer.utx
..\Sounds\Door.uax
..\Sounds\GenericLife.uax
..\Sounds\Special.uax
..\Sounds\ThrowObject.uax
..\StaticMeshes\Generic_Mesh.usx
..\StaticMeshes\prog\generic_obj.usx
..\Textures\0_0_Training_tex.utx
..\Textures\3_4_Severo_tex.utx
..\System\EchelonIngredient.u
..\Sounds\Gun.uax
..\System\EchelonGameObject.u
..\Animations\ESkelIngredients.ukx
..\Sounds\Metal.uax
..\Animations\ETrk.ukx
..\StaticMeshes\2-1_cia_obj.usx
..\System\EchelonHUD.u
..\Animations\ESam.ukx
..\Maps\menu\menu.unr             // <--- # 55
..\Textures\2_2_Kalinatek_tex.utx
..\StaticMeshes\2_2_Kalinatek_OBJ.usx
..\System\EchelonPattern.u
..\Sounds\S3_4_2Voice.uax
..\Sounds\S3_4_3Voice.uax
..\Sounds\S2_2_2Voice.uax
..\Sounds\S2_1_2Voice.uax
..\Sounds\S5_1_2Voice.uax
..\Sounds\S3_2_2Voice.uax
..\Sounds\S4_2_2Voice.uax
..\Sounds\S4_1_1Voice.uax
..\Sounds\S1_2_1Voice.uax
..\Sounds\S1_1_2Voice.uax
..\Sounds\S0_0_3Voice.uax
..\Sounds\S3_2_1Voice.uax
..\Sounds\S4_2_1Voice.uax
..\Sounds\S1_3_3Voice.uax
..\Sounds\S0_0_2Voice.uax
..\Sounds\S4_3_2Voice.uax
..\Sounds\S1_1_1Voice.uax
..\Sounds\S2_2_1Voice.uax
..\Sounds\S4_3_1Voice.uax
..\Sounds\S5_1_1Voice.uax
..\Sounds\S4_1_2Voice.uax
..\Sounds\S2_1_1Voice.uax
..\Sounds\S1_1_0Voice.uax
..\Sounds\S2_2_3Voice.uax
..\Sounds\S2_1_0Voice.uax
..\Sounds\S1_2_2Voice.uax
..\Sounds\Vehicules.uax
..\Sounds\S1_1_Voice.uax
..\Sounds\S2_1_Voice.uax
..\Sounds\S4_3_0Voice.uax
..\Sounds\S1_3_2Voice.uax
..\Sounds\Machine.uax
..\Sounds\FireSound.uax
..\Sounds\SoundEvent.uax
..\Sounds\S0_0_Voice.uax
..\Sounds\S4_3_Voice.uax
..\Sounds\S4_2_Voice.uax
..\Sounds\S5_1_Voice.uax
..\Sounds\XboxLive.uax
..\System\EchelonCharacter.u
..\Sounds\GearCommon.uax
..\Animations\ENPC.ukx
..\Sounds\Exspetsnaz.uax
..\Sounds\GeorgianSoldier.uax
..\Sounds\RussianMafioso.uax
..\Sounds\GeorgianCop.uax
..\Sounds\EliteForce.uax
..\Sounds\CiaSecurity.uax
..\Sounds\CiaAgentMale.uax
..\Sounds\ChineseSoldier.uax
..\Animations\EFemale.ukx
..\Animations\EDog.ukx
..\Sounds\GeorgianPalaceGuard.uax
```

{% collapse(preview="File Dumping Script") %}
I set a breakpoint in the prologue of a function with the string "`LinkerExists`" that I later determined to be the constructor for an object called `ULinkerLoad`. One of the arguments is the file name for this object.

When triggered, the breakpoint executes the following IDA Python script which reads the filename pointer, then the filename, outputs it to the IDA console, and continues execution:

```python
import ida_idd, ida_kernwin, ctypes
p=ida_dbg.get_reg_val("ebx")
s=b""
while True:
    c = ida_idd.dbg_read_memory(p,2)
    if not c or c == b"\x00\x00": break
    s += c; p+=2

ida_kernwin.msg("ULinkerLoad: " + s.decode('utf-16-le')+"\n")
```

{% end %}

In the above file load order I annotated file #55 which is `..\Maps\menu\menu.unr`. The `common.lin` file has 54 Linker files and #55 in the above listing happens to be the map which is loading and has its own dedicated `.lin` file. This is a strong indicator that the `common.lin` archive genuinely contains only 54 files and anything else is read from level-specific archives.

I also set a breakpoint in the function which deserializes exports (called `Preload`) and did some logging of which export is read and when a stream seek occurred:

```
ULinkerLoad: ..\System\Engine.u
ULinkerLoad: ..\System\Core.u
Export offset: 0x0,0x0,0x0,0x97,0x40f0004,0x4d,0x1b05
Seeking to/from: 0x1b05,0x10883
Export offset: 0xfffffffe,0x0,0x3,0x13d,0x70004,0x1c,0x6531
Seeking to/from: 0x6531,0x1b18
Read complete: 0xfffffffe,0x0,0x3,0x13d,0x70004,0x1c,0x6531
Seeking to/from: 0x1b18,0x654d
Export offset: 0xfffffffe,0x0,0x3,0x13c,0x70004,0x1c,0x6515
Seeking to/from: 0x6515,0x1b18
Read complete: 0xfffffffe,0x0,0x3,0x13c,0x70004,0x1c,0x6515
Seeking to/from: 0x1b18,0x6531
Export offset: 0xfffffffe,0x0,0x3,0x119d,0x70004,0x2c,0x6432
Seeking to/from: 0x6432,0x1b18
Seeking to/from: 0x6451,0x6452
Seeking to/from: 0x6453,0x6454
Seeking to/from: 0x6454,0x6455
Seeking to/from: 0x6455,0x6456
Export offset: 0xfffffffd,0x0,0x2d7,0x477,0x70004,0xb,0x1c35
Seeking to/from: 0x1c35,0x6457
Read complete: 0xfffffffd,0x0,0x2d7,0x477,0x70004,0xb,0x1c35
Seeking to/from: 0x6457,0x1c40
Export offset: 0xfffffffd,0x0,0x2d7,0x46d,0x70004,0xb,0x2736
```

{% collapse(preview="Export Preload Script") %}

IDA Python breakpoint script at `Preload` entry, identifiable by the string "`SerialSize`" **and** after the deserialization routine is called:

```python
import ida_dbg, ida_idd, ida_kernwin, ctypes, time

export_addr=ida_dbg.get_reg_val("ebp")

class_index = int.from_bytes(ida_idd.dbg_read_memory(export_addr, 4), "little")
super_index = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 4, 4), "little")
package_index = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 8, 4), "little")
object_name = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 12, 4), "little")
object_flags = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 16, 4), "little")
serial_size = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 20, 4), "little")
serial_offset = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 24, 4), "little")

edx=ida_dbg.get_reg_val("edx")

properties = [class_index, super_index, package_index, object_name, object_flags, serial_size, serial_offset]

ida_kernwin.msg("Export data: " + ",".join(hex(n) for n in properties) +"\n")
```

{% end %}

There is really no discernable pattern to the loads at all. The file/export load order seems to be just satisfying the dependency graph (exports required for parents/properties of yet-to-be-parsed types) for requested objects from the C++ side of the house.

I think an acceptable compromise to doing this statically would be requiring dumping the file/export load order from the game... but more work is needed to prove the viability of this approach.

I adjusted my program to read my logged lines into a queue of exports to be parsed, using the **completed** reads (lines starting with `Read complete` rather than `Export offset`). It then attempted to find the matching export in the export table across any package, and read its size. Repeat until the next Linker object is encountered, parse that, add it to the list, and repeat.

This quickly proved to be non-viable with my very barebones program. I woudl hit a point where I failed to find a matching export for the line logged, presumably because I was not reading the correct amount of data required to reach the next Unreal Package where that export was declared.

This was either a bug, or maybe some of the types attempt to seek+read without triggering a `Preload()`. At any rate, I had now invested a week or longer on the static approach with no data successfully dumped yet.

## Dumping at Runtime

At some point during the above research, I discovered the [EnhancedSC](https://github.com/Joshhhuaaa/EnhancedSC) project -- a community patch for Splinter Cell 1 on PC which fixes bugs, adds gameplay improvements, and has folks who certainly know the game engine better than me. I joined their Discord and asked if anyone knew about this format and they said that it's been a dead end for anyone who's bothered.

They were quite interested though in any progress achieved as they want to port some content from the Xbox versions of the games to PC. Through this community I got some great help with various theories, ideas, and introduced to tooling like [UE-Explorer](https://github.com/UE-Explorer/UE-Explorer).

After spending about a week on static recompilation I didn't want to spend even more time investing in getting things dumped only to hit a hard wall. For example discovering that the files were wildly different than expected, wouldn't work on PC, or wouldn't work with UE Explorer. I needed to dump _something_.

The game can obviously read the data fine. The thought came to me that perhaps I could just dump the data into some crappy format after it's read that makes piecing it back together easy.

While doing static analysis I came across a function that was very peculiar to me. I identified the `ULinkerLoad` function mentioned earlier by searching for the Unreal Package file magic (highlighted below), and found the following function:

[![LinkerLoad HLIL](/img/splinter-cell/linker_load.png)](/img/splinter-cell/linker_load.png)

As expected, the file magic is checked against what's read from disk. But there's another result for the magic in a different function that is **setting** some structure's field to the magic:

[![SerializeLinker HLIL](/img/splinter-cell/linker_save.png)](/img/splinter-cell/linker_save.png)

And what is the purpose of this code? As it turns out, user game saves are just Unreal Objects serialized in the same format -- sans compression and other oddities that go along with it!

[![SaveObject HLIL](/img/splinter-cell/save_fn.png)](/img/splinter-cell/save_fn.png)

### Patching OG Xbox Binaries

In order to do interesting things, we need to run our own code alongside the game. Debugger scripts are simply too slow and unreliable, so we need something running in the emulator or on a physical device. It'd also be cool if I could write a QEMU plugin for the emulator... but that's another rabbit hole.

Injecting code into a game on Windows or Unix is easy. You can `CreateRemoteThread()` or DLL hijack on Windows, and on Unix use `LD_PRELOAD`. On Xbox 360 you can "inject" persistent DLLs. On original Xbox, you have one process with (as far as I know), no DLLs.

This could probably be a blog post on its own since modern information is pretty scarce (RIP XboxHacker.org), but there are at least two tools I know of that can be used to manipulate original Xbox executables.

1. The Python library [pyxbe](https://github.com/mborgerson/pyxbe)
2. The CLI tool [XboxImageExploder](https://github.com/grimdoomer/XboxImageXploder)

Both of these tools allow you to add a new section to an executable and basically create a code cave that you can use for placing additional code or data. When the system loads the image, it maps that newly added section with the appropriate permissions. You then need to patch some place in the original executable so that your code runs.

Using XboxImageExploder and XePatcher [I was able to write a patch](https://github.com/landaire/SplinterCellDumpPatch/blob/main/SplinterCellFileDumper.asm) which calls the serialization routine on an object after it gets loaded into memory.

**tl;dr** of the patch:

1. Define a hook point at the end of the`LoadMap()` function. This definition will cause XePatcher to write these instructions that jump execution to `Hack_LoadMap` at the declared file offset.
2. `Hack_LoadMap` calls `Hack_DumpAllLinkers` and does the standard epilogue cleanup for `LoadMap()` which won't be executed since we hijacked execution
3. `Hack_DumpAllLinkers` iterates a global list of `Linker` objects and calls `Hack_DumpFile` with that linker as an argument.
4. `Hack_DumpFile` ensures that the output directory for the given `Linker` file is created, then calls the game-provided function which serializes the `Linker` to that path. For example, the `..\System\Engine.u` linker file from the `common.lin` file will be written to `z:\System\Engine.u`.

```asm
;---------------------------------------------------------
; At the very end of the LoadMap() routine
;---------------------------------------------------------
; file offset, not a VA
dd      73698h
dd      (_load_map_return_end - _load_map_return_start)
_load_map_return_start:

    ; Jump to our detour function
    push    esi
    mov     eax, Hack_LoadMap
    jmp     eax

_load_map_return_end:


_Hack_LoadMapCalled:
    dd      0

_Hack_LoadMap:
    mov     eax, Hack_DumpAllLinkers
    call    eax

    mov     eax, Hack_LoadMapCalled
    mov     dword [eax], 1

    _load_map_restore_registers:
    ; return value that we clobbered in the
    ; hook
    pop     eax

    ; Since we patched in the prologue, we will just
    ; do the register restore ourselves
    pop     edi
    pop     esi
    pop     ebx
    mov     esp, ebp
    pop     ebp
    retn    8

_Hack_DumpAllLinkers:
    push    ebx
    push    esi

    %define g_ObjectLinkers 0033c42ch

    ; Load the linker count
    mov     ebx, [g_ObjectLinkers + 4]
    test    ebx, ebx
    jz      _dump_all_linkers_restore_registers

    ; esi will be our index
    mov     esi, 0

    _dump_all_linkers_linker_loop_start:

    cmp     esi, ebx
    jz      _dump_all_linkers_linker_loop_finish

    ; Iterate the linkers
    mov     eax, [g_ObjectLinkers]
    mov     ecx, esi
    imul    ecx, 4

    add     eax, ecx
    mov     eax, [eax]
    push    eax
    mov     ecx, Hack_DumpFile
    call    ecx
    add     esp, (4 * 1)

    _dump_all_linkers_linker_loop_end:
    inc     esi
    jmp     _dump_all_linkers_linker_loop_start

    _dump_all_linkers_linker_loop_finish:
    _dump_all_linkers_restore_registers:
    pop     esi
    pop     ebx
    ret

_Hack_DumpFile:
    ; Load the argument representing the
    ; object that's being saved
    mov     eax, [esp + 4]

    ; Save registers
    push    edi
    push    esi
    push    ebx

    mov     edi, eax

    _dump_file_do_dump:

    ; Iterate the object's exports and save their flags

    ; ==== NOT USED
    ; Grab the export data pointer
    ;mov     ecx, [edi + 0x88]
    ; Grab the number of exports
    ;mov     ebx, [edi + 0x8C]
    ; ==== NOT USED

    ; Allocate space for the file path
    sub     esp, 0x200


    ; Grab the linker's filename
    mov     eax, [edi + 0x98]

    ; Put the input filename in esi
    mov     esi, eax

    ; If the input filename is empty, jump to the cleanup routine
    ; since this is not a file that's in the packed .lin
    cmp    word [eax], 0
    jz     _Hack_DumpFile_Done

    ;===== DIRECTORY CREATION
    ; The file path is located at the beginning of the stack
    mov     ebx, esp

    ; Set the filename on the stack to `z:`
    ; This has to be a char*, not a wchar_t*
    mov     byte [esp], 'z'
    mov     byte [esp + 1], ':'

    ; This will hold our position in the path we're building
    mov     ebx, 0

    _Hack_DumpFile_File_Directory:

    ; We are looking for a backslash
    ; this is wchar_t `\`
    push    0x005c
    ; Grab the position of the last backslash for the
    ; input file
    push    esi
    mov     eax, appStrchr
    call    eax
    add     esp, (4 * 2)

    ; Not found
    test    eax, eax
    jz      _Hack_DumpFile_Directory_Finish

    ; We found a slash -- check if we've discarded the first
    ; bit of data before the slash (it's expected to start
    ; with "..\" )
    test    ebx, ebx
    jnz     _Hack_DumpFile_File_Directory_Create_Directory

    ; Update ebx to point to the first slash so we can use it
    ; for later copying.
    mov     ebx, eax
    jmp     _hack_dumpfile_directory_end

    _Hack_DumpFile_File_Directory_Create_Directory:

    ; Skip the Z: part for the dest file path
    lea     ecx, [esp + 2]
    push    edx
    push    esi
    ; Start of the linker's file path
    mov     esi, ebx

    ; Copy from ebx to eax
    _hack_dump_file_copy_directory_loop:
    cmp     esi, eax
    je      _hack_dump_file_copy_directory_loop_finish

    mov     dl,   [esi]
    mov     [ecx], dl
    inc     ecx
    ; we're doing some janky wchar_t to char
    ; conversion tricks
    add     esi, 2

    jmp     _hack_dump_file_copy_directory_loop

    _hack_dump_file_copy_directory_loop_finish:
    ; Add null terminator
    mov     byte [ecx], 0

    pop     esi
    pop     edx

    mov     ecx, esp
    ; Make sure we don't clobber eax
    push    eax

    ; Attributes
    push    0x0
    ; Create this directory
    push    ecx
    mov     ecx, CreateDirectory
    call    ecx
    ; cdecl function, it cleans up

    pop     eax

    _hack_dumpfile_directory_end:
    ; Save the position
    lea     esi, [eax + 2]
    jmp     _Hack_DumpFile_File_Directory

    _Hack_DumpFile_Directory_Finish:

    ; Set the file path we want to copy
    mov     esi, ebx

    ;===== FILE CREATION

    ; The file path is located at the beginning of the stack
    mov     ebx, esp

    ; Set the start of VeryLongString to `Z:`
    push    ZDrive
    push    ebx
    mov     eax, wstrcpy
    call    eax
    add     esp, (4 * 2)

    ; Set the copy target to the bytes immediatley
    ; following `z:`, so the result should be
    ; `z:\filename`
    lea     eax, [ebx + 4]

    ; Copy the filename to the path buffer
    push    esi

    ; Set ESI to the full file path for later use
    mov     esi, ebx

    push    eax
    mov     eax, wstrcpy
    call    eax
    add     esp, (4 * 2)

    ; Error
    mov     edx, dword [GlobalError]
    ; InOuter
    mov     eax, [edi + 2Ch]

    ; Pad size?
    push    0xFFFFFFFF
    ; Conform
    push    0x0
    ; Error
    push    edx
    ; Filename
    push    esi
    ; TopLeveLFlags
    push    -1
    ; Base
    push    edi
    ; InOuter
    push    eax

    ; ( UObject* InOuter,
    ;   UObject* Base,
    ;   DWORD TopLevelFlags,
    ;   const TCHAR* Filename,
    ;   FOutputDevice* Error=GError,
    ;   ULinkerLoad* Conform=NULL );
    mov     eax, UObject_SavePackage
    call    eax
    add     esp, (7 * 4)


    _Hack_DumpFile_Done:

    ; Restore the stack to clean up the file
    ; path
    add     esp, 0x200

    ; Restore the export flags

    _dump_file_restore_registers:

    ; Restore saved registers
    pop     ebx
    pop     esi
    pop     edi

    ret

```

_Why assembly?_ Sunk cost and not wanting to figure out tooling required to compile C to shell code targeting this platform. The functions could be written in C. The detour hooks must remain assembly.

## Results

We can now read the output files in UE Explorer, and even run the Xbox main menu and the in-engine cinematic from the first level on PC... albeit with some bugged lighting and textures. Anything past that first level cinematic, including the interactive bit of the level itself, has failed to load.

The above patch, dumping at `LoadMap()` end, resulted in the most reliable file dumping out of my many experiments. At the end of this function it seems nearly all data is read and ready to go, but there are definitely a couple of objects deserialized after this point. Dumping after all object reads are complete though actually seems to make things worse -- maybe because some object properties have changed in-memory from their default values?

Loading an Xbox file in UE Explorer:

[![Engine.Engine package in UE Explorer](/img/splinter-cell/ue_explorer.png)](/img/splinter-cell/ue_explorer.png)

First level cinematic which should have a dimly-lit hallway with shadows:

[![Training Mission Load](/img/splinter-cell/level_load.webp)](/img/splinter-cell/level_load.webp)

Swapping a texture had some problems:

[![Bugged Textures](/img/splinter-cell/corrupt_textures.png)](/img/splinter-cell/corrupt_textures.png)

In fact, the textures were just straight up incomplete data. Since literally every texture object had a small size I figured that between the time the object was deserialized and the point I dumped it the original texture data must have been transformed to the target format and the original free'd.

To confirm my assumption, I set a breakpoint in the function which kicks off object deserialization so that it would break immediately before:

{% collapse(preview="Targeted Export Breakpoint Code") %}

I set a breakpoint in the `Preload()` routine immediately before object deserialization with the following script.

```python
import ida_dbg, ida_idd, ida_kernwin, ctypes, time

export_addr=ida_dbg.get_reg_val("ebp")

serial_offset = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 24, 4), "little")

class_index = int.from_bytes(ida_idd.dbg_read_memory(export_addr, 4), "little")
super_index = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 4, 4), "little")
package_index = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 8, 4), "little")
object_name = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 12, 4), "little")
object_flags = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 16, 4), "little")
serial_size = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 20, 4), "little")
serial_offset = int.from_bytes(ida_idd.dbg_read_memory(export_addr + 24, 4), "little")

edx=ida_dbg.get_reg_val("edx")

properties = [class_index, super_index, package_index, object_name, object_flags, serial_size, serial_offset]

ida_kernwin.msg("Export offset: " + ",".join(hex(n) for n in properties) +"\n")

# Break only when the object offset matches my target
return serial_offset == 0x11f65f
```

{% end %}

Then I set a breakpoint in the data read function and examined where the texture data from disk was being copied to. I had to do some stepping through to figure out where this destination pointer originated, then located immediately next to _that_ pointer is the dynamic array's length and capacity. Set a Memory Write breakpoint on the length field and wait for it to go to zero. Wherever it happened, that was the code and the `realloc` immediately following had to simply get nop'd out to prevent the texture data from being evicted.

After adjusting my patch and dumping data again I noted that the texture file's size changed dramatically and I now had some nice textures to look at:

[![CIA Flag Texture](/img/splinter-cell/cia_flag_texture.png)](/img/splinter-cell/cia_flag_texture.png)

[![HUD Texture](/img/splinter-cell/hud_texture.png)](/img/splinter-cell/hud_texture.png)

## General Issues With Dumping

Since exports are lazy loaded, you can only dump what's used in a level. The main menu uses some functionality from `Engine` and `Core`, but not all of it. So if I load the main menu map and dump all the linkers when it's finished loading, I will only have a partial representation of `Engine` and `Core`.

In the same vein, anything unreferenced or unused which might by happenstance be in the archive cannot be easily recovered without intelligent brute forcing since you don't know where its data starts. e.g. the main menu has some brushes which are in the export table but appear to be unused, so nothing ever triggers their appropriate load.

## Next Steps

While we've had some wins with dumping data and I feel I've accomplished a lot, I'm not going to be satisfied until I can cleanly dump anything I want from the game. A major milestone would be to get the training mission on Xbox completely working on PC. I'm going to try to make some strides here and if I hit a wall, I'll at least try to dump some data from the review copy of the game.

This format can certainly be read statically _with_ load-order knowledge from the game engine. I'm hoping for now that someone from the community can use the work presented in this blog post to get it working in Unreal-Library.

Static recompilation would be a much more general approach which I hope only requires two debugger breakpoint scripts to dump package filenames and export loads on a per-game basis rather than a binary patch. We already have this for SC1. The difficulty would be in contributing to UELib (or some other project) so that it can match the game's exact I/O behavior and deserialize multiple packages simultaneously using the load-order data. If this interests you, [check out the issue I filed in the project repo](https://github.com/EliotVU/Unreal-Library/issues/125).

If you have questions, feel free to reach out to me on Twitter: [@landaire](https://x.com/landaire).

## Thanks

- Grimdoomer for getting me up to speed with writing OG Xbox patches and for listening to my rants about this format.
- To the EnhancedSC developer community for helping inspect my dumped files and for investing in what success we've had so far.
- EliotVU for developing the great UE Explorer and UELib.
- The folks who documented their own findings on this format before me. Every little bit of information helps.
