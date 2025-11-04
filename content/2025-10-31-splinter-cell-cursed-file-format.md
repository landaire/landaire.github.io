+++
title = "The Most Cursed Binary Format I've Yet to Encounter"
summary = "_\"I’ve had enough reasonable formats fired at me in my time to tell you that wasn’t one_\" - Sam Fisher"
template = "toc_page.html"
toc = true
date = "2025-10-30"

[extra]
draft = true
+++

[Splinter Cell (2002)](https://en.wikipedia.org/wiki/Tom_Clancy%27s_Splinter_Cell_\(video_game\)) was one of the first games I had on the original Xbox, probably sometime in 2003, and to this day remains one of my favorite games of all time. It was developed by Ubisoft using Unreal Engine 2 which was licensed from Epic Games.

Videogames were how I got into programming/hacking, and I still enjoy data mining and exploring cut content from games. While recently looking into cut content for Splinter Cell, I was kind of surprised that there isn't really much information on the topic aside from [a review copy](https://hiddenpalace.org/Tom_Clancy%27s_Splinter_Cell_\(Sep_13,_2002_prototype\)) of the game which contained two levels cut from the Xbox version.

Naturally, I decided to _legally backup my personal disc copy of the game_ and get got to digging on the files.

**Before I dive into a bunch of technical details**, let me state my core objective: examine the format of the game data and attempt to see if there's any cut content. Debug menus, voice lines, weapon concepts, levels that are unreachable through normal game progression, etc.

The (truncated) file tree looks like this:

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

For those familiar, `.bik` files are Bink Video files and `.tga` are images... but `.lin` is new to me.

In Splinter Cell the maps have separate parts to them. So in the training mission `001_Training`, you have `0_0_2_Training.lin` likely for the first part, `0_0_3_Training.lin` for the second, etc. I instantly thought that `common.lin` might contain data common to both of these parts as a way to reduce file size as this is a fairly common technique. The Halo games for instance have a `shared.map` containing assets which are shared across most maps, and load data at a fixed address so that the file can be trivially transmuted from a binary blob to its in-memory structs.

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

- 0x0..0x4 and 0x4..0x8 are low-value little-endian 32-bit integers (`0x00000004` and `0x0000000C`)
- At offset `0x8` is what appears to be a zlib-compressed chunk of data (whenever I see a bunch of `x`-like characters in the ascii view, or the `79 9c` sequence, I immediately think zlib).
- There's another sequence of this at offset `0x14`, which happens to be `0xC` bytes past the offset of the zlib data (`0x8`).

So presumably the format here is `{decompressed_data_len, compressed_data_len, zlib_block[compressed_data_len]}` repeated.

So far so good. I wrote a quick tool to decompress the archive and without a hitch ended up with a 64k file containing 4 `u32`s prefixing it, which since these 4 are in their own dedicated zlib-compressed chunks I consider to be separate from the main data:

```
uncompressed_data_size: 0x648EEE
texture_cache_size (? - later used when calling D3DDevice_CreateTexture2): 0x1B0000
vertex_buffer_size (? - ditto, D3DDevice_CreateVertexBuffer2): 0x6740
index_buffer_size (? - ditto, XGSetIndexBufferHeader): 0xD38
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

Just to save some blog space on my trial and error here, I'm going to drop some of the resources I found which discuss this format:

- [https://oldunreal.com/phpBB3/viewtopic.php?t=4885](https://oldunreal.com/phpBB3/viewtopic.php?t=4885)
- [https://zenhax.com/viewtopic.php@t=1049.html](https://zenhax.com/viewtopic.php@t=1049.html)
- [https://reshax.com/topic/1421-ubisoft-unreal-engine-2-open-season-2006-video-game-umd-also-lin-xbox-xbox-360-pc-and-liv-latter-being-exclusive-to-xbox-360/](https://reshax.com/topic/1421-ubisoft-unreal-engine-2-open-season-2006-video-game-umd-also-lin-xbox-xbox-360-pc-and-liv-latter-being-exclusive-to-xbox-360/)
- [https://www.unrealarchive.org/wikis/unreal-wiki/Legacy:UMOD/File_Format.html](https://www.unrealarchive.org/wikis/unreal-wiki/Legacy:UMOD/File_Format.html)

The last two posts in particular had structure info that was helpful in figuring out the packed int format (think UTF-8 and its variable-length encoding) and a couple unknown vars.

What I gathered from all of these posts was that over time, nobody's really been able to figure out this format's quirks sufficiently to unpack the data.

**My objective has now changed:** I now want to reverse engineer this file format and be able to dump individual files from this filesystem. Then I can achieve my core goal of looking for cut content. Then I can maybe play the game.

## tl;dr of the general structure

`common.lin` has a different layout from the other files that looks roughly like:

```c
/* ==== LIN-Specific Prefix ==== */

// These three, from research + reverse engineering, should not be considered
// as part of the "whole" file
uint32_t        maybe_load_address; // 5C 58 9E 13 in common.lin
compressed_int  name_length;        // 0 in common.lin
cstr            name;

/* ==== Begin "true" common.lin file header ==== */

uint32_t        magic;              // 0x9fe3c5a3 in little endian, i.e. A3 C5 E3 9F

// unk_address - load_address gives you the start of the file table, relative to the magic?
uint32_t        unk_address;        // B4 92 9B 13, suspiciously similar to maybe_load_address
uint32_t        load_address2;      // 5C 58 9E 13 same as maybe_load_address

uint8_t         unknown[8];         // 01 00 00 00 04 2A D6 FE
compressed_int  file_entry_count;

struct FileEntry {
    compressed_int  name_len;
    cstr            name;
    uint32_t        offset;
    uint32_t        len;
    uint32_t        unk;
}
```

Then immediately following the `FileEntry` table are 54 Unreal Engine Package files, in sequence, whose magic are `0x9E2A83C1` that presumably map to the files in the file table.

The above is from looking at the `common.lin` file. The map-specific files like `menu.lin` and `0_0_2_Training.lin` do not have the file table, but they do have the first 3 fields (and a non-null string like "menu\x0" for the name field) then a sequence of UMod files.

But the problems with parsing this data start with the file table.

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

At first glance the files seem to be laid out linearly, aligned to a register-width boundary. Except, notice that last file's offset... `0x9600F0`. This is way outside of the range of my `0x648eee`-length file, and this file list contains 3,582 files! Not 54 as expected from the count of UMod magics! The latter could be explained by not every file in this container being UMod, but the offsets are *extremely* wrong.

### File Reading

After debugging the game in the Original Xbox emulator [xemu](https://xemu.app/), I was able to find the routine which opens the file, as well as the function which reads and decompresses data.

{% collapse(preview="Function Identification Methodology") %}

If anyone's curious on the methodology: I identified `NtCreateFile`, set a breakpoint, recorded the `HANDLE` returned for the file path I cared about, then set a breakpoint at `NtReadFile` and broke when the input `HANDLE` matched the expected value. The call stack/stepping from here helped identify interesting callers. Alternatively, the string "`unknown compression method`" is useful in finding the decompression routine `inflateInit2`.

This is not super relevant to the blog post which is why it's in this little collapse section. In general I hate reading posts like this that skip over a detail I'm interested in like it's just common knowledge how something is done, so I'm trying to avoid doing that :)

{% end %}

_Note: Click images to see in higher res_.

[![Compressed read function](/img/splinter-cell/compressed_read_fn.png)](/img/splinter-cell/compressed_read_fn.png)


[![Compressed read function high-level IL](/img/splinter-cell/compressed_fn_hlil.png)](/img/splinter-cell/compressed_fn_hlil.png)

This function basically checks the read length against how much data it has precached in its decompressed data buffer. It will then copy as much data as it can to the output buffer, then read the next block of compressed zlib data into its precache buffer. Repeat this process until the request is satisfied.

Identifying this function was pretty important for my reverse engineerin process. I could now set breakpoints on the branch which copies data to the output buffer and see who's calling this function when data is read from offsets I care about.

I stepped through this code, set memory read breakpoints on interesting addresses, and noted something interesting!

Those "addresses" from the header? Those are actually passed to what I can only guess is a `Seek` routine which updates the `position` property of the file reader, then makes an indirect call to another function which **literally does nothing**.

The entire content of the function is:

```
retn    4
```

That's it.

Then the reads just continue from their last position? Since the function is an indirect call, I can only assume that I was looking at some composed C++ object where the _outer_ class object updates its own position in `Seek()`, then calls its underlying file reader's `Seek()` which is a nop?

The set `position` is pointless! After setting memory read breakpoints on it, it's only ever used in their file reader equivalent of `FTell()`. It doesn't affect reads at all.

The reason for the `Seek()` being a no-op is likely because the underlying file reader is reading directly from the compressed buffer. Since you cannot reasonably map an uncompressed data offset to a compressed offset and you don't want to decompress the same block multiple times, the format must be designed to ignore seeks and just read data linearly.

... the `.lin` extension makes a lot more sense.

So in order to read these files, you have to assume that the offsets don't exist and you cannot seek forward/backward. Easy enough.


### Load Order Matters

We still have a problem that has not been addressed: why does the file table have a large count of files with bad offsets?

I continued to use breakpoints inside of the file read function to trace where interesting bits of data were read, and forced the debugger to break when the first bit of interesting data was read immediately following the file table.

Eventually I traced the read back far enough to find this function, `StaticLoadObject`:

[![StaticLoadObject implementation](/img/splinter-cell/static_load_object.png)](/img/splinter-cell/static_load_object.png)

This function calls `ResolveName` which I was able to add logging to:

[![ResolveName implemntation](/img/splinter-cell/resolve_name.png)](/img/splinter-cell/resolve_name.png)

Through the debugger I was able to see that the argument passed to this function is `ini:Engine.Engine.GameEngine`.

This gets parsed as:

- `ini:Engine.Engine` <- the INI table to read from
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

So the resulting value returned from this function is `Engine.GameEngine`.

This is then used to resolve the **package** `Engine` and its **exported object** `GameEngine`. The game binary looks for the file `Engine` in its available sources, inlcuding what's read from the LIN file table, and maps that to `System\Engine.u`. My tool that reads the file table shows me the following data:

```rust
FileEntry {
    name: System\\Engine.u,
    offset: 0x13482120,
    len: 0x127DA1,
    unk: 0x0,
},
```

Except the file start offset + len don't make sense. Even if I assume the `Engine.u` file is the first file immediately following the file table, using the length to read it appears to land right in the middle of some string data?

```
┌────────┬─────────────────────────┬─────────────────────────┬────────┬────────┐
│00154330│ 09 45 4d 65 73 68 53 46 ┊ 58 00 10 00 07 00 1b 43 │.EMeshSF┊X......C│
│00154340│ 68 61 6e 64 65 72 6c 65 ┊ 72 43 72 79 73 74 61 6c │handerle┊rCrystal│
│00154350│ 50 61 72 74 69 63 75 6c ┊ 65 00 10 00 07 00 12 46 │Particul┊e......F│
└────────┴─────────────────────────┴─────────────────────────┴────────┴────────┘
```

I'll save some time and just say that I did not identify the wrong file. The lengths just don't matter, and are wrong. The reader in the game engine must just read the data in-order using its self-description?

Ok whatever. The Unreal Engine Package file format has been [well documented](https://eliotvu.com/page/unreal-package-file-format) and includes some sizes in its header. I mapped this to the following Rust struct:

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

And of course, the offsets in this format make no sense. But the counts look good:

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

Now with my tool updated to read these tables I have imports that look like:

```rust
Imports:
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
    data: None,
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
    data: None,
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
    data: None,
}
```

So the `GameEngine` has export index `0xEFB` and its data is supposedly located at offset `0xC50DB` relative to the package start. You guessed it though, its offset is wrong! The data is instead read immediately after the export table.

### Export Data

Up to this point we know:

1. You cannot seek in the file reader.
2. The offsets are fake and don't matter.
3. The sizes (at least in the file table, and I soon realized in the export data) are incorrect.
4. The `GameEngine` which we know is the first object requested by the game engine is located at index `0xEFB` in the `Engine` package.

Now, to achieve my goal of dumping these files I attempted to simply sum the size of these exports... but trying a combination of that calculated size + any of the `{end_of_export_table, start_of_file}` offsets landed me in weird places with other Unreal Engine Package files inbetween.

{% collapse(preview="Publicly Available Parsing Source Code") %}

I'll say that up to this point I mostly did this work through pure reverse engineering, using only sources already mentioned. Leaked Unreal Tournament 2004 source code can be found easily online and uses a very similar Unreal Engine version. [UE Explorer](https://github.com/UE-Explorer/UE-Explorer) and its foundational library [Unreal-Library](https://github.com/EliotVU/Unreal-Library) also exist and supports loading packages from basically every version of Unreal Engine. Some of my reverse engineered function names and data structures got slightly better after learning about these resources.

Since it's a bit of a gray area to suggest looking at leaked source, for the purposes of suggesting looking at source I'll refer to UE Explorer. But I think it's dishonest to simply ignore that the engine source from around the time exists out there.

{% end %}

By referencing source code such as [Unreal-Library](https://github.com/EliotVU/Unreal-Library), the following high-level parsing logic can be observed:

1. An exported object is requested by the game. If it isn't loaded already, the export is lazy loaded.
2. Lazy loading requires resolving the `super` type. For some things this is the `Class` or `Struct` base types, for other things this is a different parent class which will eventually have `Class` as its parent type.
3. Exports have properties which can be of varying size. As you read an export, you deserialize its data as described by its `serial_size` and `serial_offset` fields, and however the C++ side defines the deserialization routine. Type information is saved, but coupled to the engine's definitions.

Which visually results in something like:

![Export parsing flow](/img/splinter-cell/export_load_flow_diagram.svg)

The important part is that **you need to have full type information and knowledge of how each C++-implemented type is parsed in order to parse the export, and reading one export may trigger resolving of imports (in your self) file which trigger deserialization of exports in another file**.

## Making Sense of Everything

I really, really would like to avoid doing any runtime dumping that requires playing the game in an emulator or physical console. It doesn't scale well to other games that may have a similar format and is generally less flexible. But doing runtime observations are extremely useful in making sense of the format, so I went ahead and added some logging to get an idea of the _file_ read order from the compressed archive when booting the game:

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
I set a breakpoint in the prologue of a function with the string "`LinkerExists`" that I later determined to be the constructor for an object called `ULinkerLoad`. One of the arguments is the file name:

I set the breakpoint to execute the following IDA Python script which reads the filename pointer, then the filename, and outputs it to the IDA console:

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

In the above file load order I annotated file #55 which is `..\Maps\menu\menu.unr`. The `common.lin` file has 54 Unreal Engine Package files, and #55 happens to be the "map" which is loading and has its own dedicated `.lin` file: `menu.lin`.

I also set a breakpoint in the function which deserializes exports (`Preload`) and did some logging of which export is read and when a stream seek occurred:

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

IDA Python breakpoint script at `Preload` entry, identifiable by the string "`SerialSize`" **and** after the deserialization routine is calld:

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

I think an acceptable compromise to doing this statically would be requiring dumping the export load order from the game.
