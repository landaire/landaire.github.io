+++
title = "Reverse Engineering Binaries With AI"
description = "The barriers have been lowered"
summary = "The barriers have been lowered"
template = "toc_page.html"
toc = true
date = "2026-03-08"

[taxonomies]
tags = ["re", "ai"]

[extra]
hidden = false
+++

## Getting Into Security

In middle school the gateway drug known as _Halo 3_ and unapproved mods shared on the game's File Share system got me interested in programming and security.

Through these mods and YouTube tutorials I discovered the (long defunct) Xbox-Tampers forum, followed tutorials on how to edit map files in a hex editor and make very basic MSN Messenger nudge bomb applications, and met some great people through that site who I'm still friends with.

I remember the struggles in the late 2000s and early 2010s of using ~~cracked~~ expensive copies of IDA Pro to reverse engineer bits of the Xbox 360 to better write modding tools, and begging my friends who were much better than me (like [@carrot_c4k3](https://x.com/carrot_c4k3), [Xenomega](https://github.com/Xenomega), and [@Grimdoomer](https://x.com/Grimdoomer/)) to help me reverse some Xbox 360 OS functions that I could not understand.

I've invested a lot of time and energy to try to get better at these things over the past 18 or so years. It's not what I live and breathe anymore and I'm not insanely cracked at RE, but I feel I've gotten pretty decent at being able to throw a binary into static analysis tool and with disassembly/pseudocode can reasonably understand what's going on in an an application.

I've worked professional as a security engineer for the past 10 years and of course, AI "happened" and it's shaken up a lot of things, but I've still felt fairly comfortable about my skills not being terribly threatened. I've seen people try traditional static analysis tools, data flow analysis, etc., and all tooling falls short somehow, so surely this won't be too different in the near-term -- especially for such a niche skill -- right?

I think I was wrong.

## Programming w/ AI

For non-ethical reasons I've felt pretty anti-LLM for coding. Mostly because it made me feel disconnected, dumb, and lose context. When Copilot first came out I gave it a shot but I felt like a monkey just smashing tab to have it complete some code. My subscription was soon cancelled as I felt like I was losing my edge when I didn't have AI assistance readily available.

At my job, however, AI adoption is being driven fairly hard and I've taken to using Claude Code for some of my side projects to understand AI usage better.

A couple years ago I created a program called [WoWs Toolkit](https://landaire.net/wows-toolkit/) which for about the last year went without any major updates because I just lost the steam to context switch all the time.

It's a fairly straightforward application designed to datamine the naval warfare videogame _World of Warships_, but has some slightly complicated internals which are used to read game files, understand the match replay format, etc:

![WoWs Toolkit](/img/ai-reverse-engineering/replay_inspector.png)

I've had people in the community ask for various features over time which were mostly filed away in the "Nice To Have Eventually" folder as some require significant time investment.

One requested feature was the ability to read the game's proprietary 3D model format to understand the armor layout of ships in the game better. I started to reverse engineer the format about a year ago, lost steam, and just kind of dropped it.

There are various moving parts for that, some of which I'd already done:

1. Reading the game's virtual filesystem (VFS) without intermediate tools.
2. Understanding the game's "GameParams" database which holds meta information about ships, upgrades, each component's 3D model path, etc.

And parts I'd not done:

1. In the main VFS is a file called "assets.bin" which is a format very similar to the VFS it's contained within, but different enough to break my parser and it also had a second string table that I hadn't yet understood.
2. Any research on the `.geometry`, `.visual`, or `.model` files -- all of which are required to paint a complete picture of the mesh, model positions, world transform, etc.
3. Any understanding of how ship armor was represented and how it works in relation to the mesh.

I was making some changes to the app and thought, "Fuck it, why not see if Claude can figure it out?"

## Claude Code + Binary Ninja MCP

I installed one of the MCP plugins for Binary Ninja, set it up in Claude Code, and gave it the following prompt:

> We have the Binary Ninja MCP running with WorldOfWarships64.exe running. There's some code I'd like you to reverse engineer in order to figure out a file format. Please document findings in G:\dev\wowsunpack\MODELS.md
>
> We're going to be reverse engineering the WoWs .geometry file format. An example file can be found here: G:\wows_dump\res\content\gameplay\uk\ship\aircarrier\BSA013_Colossus_1945\BSA013_Colossus_1945.geometry
>
> It's a 3D model format that I believe is proprietary to Wargaming's BigWorld engine. There are some magic constants in the file like `45 4E 43 44` that I've used to find a possible candidate function to start at: sub_140a5a940
>
> This has some interesting strings such as: `bufferHeader->m_magicVal == EncodedBufferHeader::EncodedMagicVal`
>
> There are other functions with this magic value too that I have not looked at. Please remember if you search the binary in binary ninja for this magic value, it will need to be little-endian encoded.
>
> If you want to write code to test, feel free to add a new command to the wowsunpack CLI and start adding code to a new models module.
>
> We should use winnow for our binary parsing. Do not commit any changes.

Then came some early results:

![Early AI analysis](/img/ai-reverse-engineering/early_analysis.png)

_Note: I'm using Claude Desktop here for no good reason. Normally I'd use the CLI or ACP interfaces._

And after processing for a bit:

![Additional AI analysis](/img/ai-reverse-engineering/later_analysis.png)

Eventually I had some 3D models extracting into a format I could load into Blender piece-by-piece:

![First 3D Models](/img/ai-reverse-engineering/first_3d_models.png)

And after more prompting, it was able to export the entire ship with its paint textures:

![Ship Model](/img/ai-reverse-engineering/yamato_full.png)

It tried to do some _very_ dumb things along the way. For example, in one of these files there's some XML data at some point. It generated code where after parsing a section header it would scan forward looking for the XML blob's opening tag and do the same from that position to find the closing tag. I had to curse and yell telling it, "You're fucking this up, stop taking shortcuts. Do this the the right way. No heuristics."

But honestly, I'm impressed with what Claude was able to do. From this very dumb prompt I was able to go from a bit of info from myself + a very surface-level parser for a _dependency_ of the model loading pipeline (not even the 3D model itself!) to code which is able to export 3D models of ships with their textures and armor models, at any LOD. And it built a custom 3D model viewer into WoWs Toolkit.

It even did some weird things I never thought of, like [cracking hashes](https://github.com/landaire/wows-toolkit/blob/36234afb178453fc262b113cfba1931d896f9fe7/scripts/crack_mfm_hashes.py) from a set of known strings in the binary to figure out items in the tree structure.

I barely wrote a line of code for this and it cost maybe ~$150 in tokens and an hour until I was able to extract bits of models:

![Early AI analysis](/img/ai-reverse-engineering/armor_viewer.png)

If you would like to read its full analysis of the 3D model format, [here is its braindump](https://github.com/landaire/wows-toolkit/blob/36234afb178453fc262b113cfba1931d896f9fe7/docs/MODELS.md). And [here is the code](https://github.com/landaire/wows-toolkit/tree/36234afb178453fc262b113cfba1931d896f9fe7/crates/wowsunpack/src/models).

## Learnings

While I really don't have much to share about the specific _thing_ being reverse engineered, I did learn quite a bit about interacting with Claude. I'm sure people who live and breathe LLMs have their own advice, but what I found personally valuable:

- Developing custom CLIs for rapid testing/iteration. I already had a CLI for interacting with game files which Claude was able to easily extend to test its analysis of the binary.
- The existing tooling beyond just that CLI was critical. Other CLI tools for examining related file formats or deobfuscating data. This wasn't just a "point it at Binja and profit" sort of deal to achieve the polished result.
- Watching the code as it streams in, or ensuring a mostly comprehensive review for reasons I've already mentioned like the AI trying to take shortcuts, is very important. I interrupted Claude many times when I noticed it was taking a subpar approach.
- My project is in Rust, and Rust has a strong type system. Having the AI use strong newtypes for things like identifiers helped quite a bit with ensuring bug-free code.
- My code was originally split into a couple different repos (one for the CLI tool and libraries, one for the UI). Swapping editor windows before all of this was kind of annoying, and it was even more annoying when trying to have the agents to cross-repo changes.
- If you want to sniff out AI-assisted or generated code changes, look for unicode symbols like the fancy Unicode equivalent of `<->` or `->`, comments in Rust starting with `//!`, or sudden introduction of section dividers like the following:

```
// ---------------------------------------------------------------------------
// Helper: parse an array at a given offset, wrapping winnow errors
// ---------------------------------------------------------------------------
```

And most importantly: there were still bugs along the way. Trying to debug some of these things and prompt for fixes without knowing specifics of how the pieces were interconnected was really annoying (e.g. ship turrets were sometimes not facing to the correct default orientation). For things I really care about being done right, I think it's still worthwhile to go through the pains myself _first_ and have AI assistance later if I can.

## Mixed Feelings

I would consider myself a low-level person who thinks about allocations in my application, the performance cost of various approaches, and I like knowing the details of how something works. I might do the wrong thing at times for certain tradeoffs, but I like to be aware of that tradeoff existing and which decision was made. For this task though?

I have no idea how it works.

Before starting this project I had zero knowledge of 3D rendering, model formats, and while I did manually reverse engineer the game's general virtual filesystem format for its packed files, I got about halfway similar virtual filesystem used for 3D model assets. I have no idea how it works beyond what I started.

I read the code as Claude went along, pointing out things that I thought were obvious anti-patterns or incorrect... but I couldn't tell you how the different ship mesh sections are read, then paired to their transformation matrix (which is located in another file).

That kind of sucks.

Don't get me wrong -- I _am_ happy that I'm giving people something they want and it otherwise may not have ever gotten done without Claude helping accelerate things. I'm also happy that the barrier to these types of tasks are lowered for a modest fee. There's just not "my code" and the iteration over failure to be proud of, and I want people to feel confident that the person behind the software fully understands what it's doing. Or supposed to be doing.

Even back in the days of asking my friends for help, I was still building a relationship with them in some capacity and they could help guide me. In some cases they would even just reverse engineer things, hand me the completed package, and explain to me the bullshit they had to understand, and I'd happily give them a shoutout for helping with the project. Now it's a one-way trip with Claude and asking it to do a brain dump.

I suppose that just like I told the AI not to take shortcuts though, I find it hard to accept **<Insert This Month's Best Model>** doing these things at the cost of building my own context, expanding my skillset to new areas, and keeping my existing skills sharp.
