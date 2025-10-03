+++
title = "Writing a PE Loader for the Xbox in 2024"
description = "Adventures in reinventing the wheel. Also: I hate thread-local storage."
summary = "Adventures in reinventing the wheel. Also: I hate thread-local storage."
template = "toc_page.html"
toc = true
date = "2024-08-13"

[extra]
#image = "/img/wows-obfuscation/header.png"
#image_width =  250
#image_height = 250
pretext = """
*If you're already familiar with PE loading, absolutely nothing new is presented in this blog post but you might learn something like I did. Full source code can be found [on our GitHub](https://github.com/exploits-forsale/solstice). [Jump to the end](#fin) to see the fruits of our labor.*
"""
+++

Emma ([@carrot_c4k3](https://twitter.com/carrot_c4k3)) is a good friend of mine. We met in 2007 from the Xbox 360 scene and have remained friends ever since. She recently participated in pwn2own in the Windows LPE category and ended up using a great bug for LPE.

The bug far exceeded the category though: this vulnerability was also a _sandbox escape_, i.e. it's in an NT syscall which is reachable from the UWP sandbox. A couple months ago she got a wild idea: why not try to port the exploit over to the Xbox One? (Modern Xboxes, not to be confused with the OG Xbox)

## Brief Primer on the Xbox One's Security

Since I'll be talking about this in the context of the Xbox, it's worthwhile to spend a moment discussing the Xbox One's security model. There's [a very great and in-depth overview of the Xbox One's security model on YouTube](https://www.youtube.com/watch?v=U7VwtOrwceo) presented by Tony Chen who is one of the folks who designed it. I highly recommend watching it if you're interested, but I'll do my best at giving a crash course:

```
┌────────────────────────────┐     ┌────────────────────────────┐
│                            │     │                            │
│                            │     │                            │
│                            │     │                            │
│                            │     │                            │
│        ERA (GameOS)        │     │         SystemOS           │
│                            │     │                            │
│                            │     │                            │
│                            │     │     │             │        │
│                            │     │     │             │        │
└────────────────────────────┘     └─────┼─────────────┼┬───────┤
               │                         │             ││ VMBus │
               │                         │             │└───────┘
┌──────────────┼─────────────────────────┼─────────────┼────────┐
│              │                         ▼             ▼        │
│              │           HostOS  ┌──────────┐ ┌───────────────┤
│              │                   │ Synthetic│ │ VSPs/Normal   │
│              └──────────────────▶│ Devices  │ │ Hyper-V Stuff │
└──────────────────────────────────┴──────────┴─┴───────────────┘
┌───────────────────────────────────────────────────────────────┐
│                                                               │
│                          Hypervisor                           │
│                                                               │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

This is a very, very simplified drawing of what you'd find on Microsoft's [Hyper-V Architecture page](https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/reference/hyper-v-architecture). The main thing I'm trying to highlight here is that there are 3 VMs with 3 different purposes:

1. HostOS, which acts very similar to your standard Hyper-V host.
2. ERA OS (aka GameOS) which is where games run.
3. SystemOS which is where applications run. Here you'll find the system shell and UWP applications from the Windows Store.

Each VM is running a very slimmed down version of Windows based on Windows Core OS (WCOS). The Hyper-V architecture is mostly what you'd encounter on a normal PC but with some additional Xbox-specific VSPs/functionality.

Missing from the above diagram is the _security processor_ (SP). The Xbox One's security processor should be the only thing on the Xbox which can reveal a title's plaintext on Xbox One. (*Random fact: Microsoft's [Pluton Processor](https://learn.microsoft.com/en-us/windows/security/hardware-security/pluton/microsoft-pluton-security-processor) is based on learnings from the Xbox One's security processor*)

The core idea behind all of this is to **make piracy extremely difficult**, if not impossible without breaking the SP. If you _do_ hack the Xbox One, you can't do it online trivially because the SP will attest that the console's state is something unexpected.

## OK, How Does This Relate to the PE loader?

Unrelated to her pwn2own entry, Emma found a vulnerability/feature in an application on the Xbox One marketplace called _GameScript_, which is an ImGui UI for messing with the [Ape programming language](https://github.com/kgabis/ape).

[Through this vulnerability](https://gist.github.com/carrot-c4k3/10fdb4f3d11ca568f5452bbaefdc20dd) Emma was able to read/write arbitrary memory and run shellcode. So we have arbitrary code execution in SystemOS, but now the problem: writing shellcode is a pain, so how can we run arbitrary *executables* easily?

We have the ability to read/write arbitrary memory and change page permissions which is enough to write a portable executable (PE/.exe) loader. Emma asked if I would write one since it would simplify the exploit development pipeline while she worked on porting her LPE exploit over and it'll be useful for homebrew later on too. Easy enough right?

**Wrong.**

## Reinventing the Wheel

The specific technique of PE loading outlined here is referred to as "Reflective PE Loading". To me this sounds like some #redteam term I'd never heard before embarking on this project, and is not very descriptive in my opinion... but a "reflective PE loader" is simply some user-mode code that can load and execute a PE without going through the normal `LoadLibrary()` / `CreateProcess()` routines .

Avoiding `LoadLibrary()` and `CreateProcess()` is very important for us since those will check for code integrity and any code we write will not be properly signed.

I took a look at the work involved and decided I wanted to write my own loader for multiple reasons:

1. I despise dealing with C/C++ build systems.

2. Since I'm targeting _Xbox Windows_ and not _desktop Windows_, I might encounter some problems and I know how to debug my own code better than someone else's.

3. On the Xbox we're required to use a PE loader for running unsigned executables until we eventually break code integrity. So we better know how it works and be able to load complex applications.

4. I don't give a shit about EDR evasion or any #redteam stuff like that.

5. We originally had some very, very strict size constraints that we found a workaround for, but we want to be able to control the loader size as much as possible.

6. It seemed simple enough at the time to just rewrite it in Rust, so I did.

For my project's base I combined two open-source Rust projects:

- [b1tg/rust-windows-shellcode](https://github.com/b1tg/rust-windows-shellcode) which provided a great template for writing and building Windows shellcode in Rust.
- [Thoxy67/rspe](https://github.com/Thoxy67/rspe) which provides a basic reflective loader.

rspe already got me most of the way there, but with a few caveats:

- It needed some cleanup (e.g. lots of unnecessary copies)
- It did not support loading imports by ordinal
- It did not support thread-local storage at all
- It did not support command line arguments
- It did not support environments with W^X mitigations
- It did not work with _shellcode-based programming_ in mind.

{% collapse(preview="What is shellcode-based programming?") %}

On that last point above you might be wondering, "What is shellcode-based programming?" Well why don't I just give an example. Here's how a `VirtualAlloc()` call in `rspe` worked before:

```rust
#[link(name = "kernel32")]
extern "system" {
    pub fn VirtualAlloc(
        lpaddress: *const c_void,
        dwsize: usize,
        flallocationtype: VIRTUAL_ALLOCATION_TYPE,
        flprotect: PAGE_PROTECTION_FLAGS,
    ) -> *mut c_void;
}

// Allocate memory for the image
let baseptr = VirtualAlloc(
    core::ptr::null_mut(), // lpAddress: A pointer to the starting address of the region to allocate.
    imagesize,             // dwSize: The size of the region, in bytes.
    MEM_COMMIT,            // flAllocationType: The type of memory allocation.
    PAGE_EXECUTE_READWRITE, // flProtect: The memory protection for the region of pages to be allocated.
);
```

And here's how this would look with shellcode-based programming:

```rust
pub type VirtualAllocFn = unsafe extern "system" fn(
    lpAddress: *const c_void,
    dwSize: usize,
    flAllocationType: u32,
    flProtect: u32,
) -> PVOID;

pub fn fetch_virtual_alloc(kernelbase_ptr: PVOID) -> VirtualAllocFn {
    // this is some macro that, using `kernelbase_ptr`, parses kernelbase's export table to find `VirtualAlloc`
    // and return its address. i.e. kind of a self-made version of `GetProcAddress`
    resolve_func!(kernelbase_ptr, "VirtualAlloc")
}

let VirtualAlloc = fetch_virtual_alloc(kernelbase_ptr);
let baseptr = (VirtualAlloc)(
    preferred_load_addr, // lpAddress: A pointer to the starting address of the region to allocate.
    imagesize,           // dwSize: The size of the region, in bytes.
    MEM_COMMIT,          // flAllocationType: The type of memory allocation.
    PAGE_READWRITE,     // flProtect: The memory protection for the region of pages to be allocated.
);
```

As you might have noticed, we're not linking against any libraries and calling those imports directly. Instead we're using indirect calls to functions whose addresses we manually resolved at runtime. All you need for shellcode development that _isn't_ painful is to find `kernelbase.dll` which can be done using the `gs` register to grab the PEB:

```rust
pub fn get_module_by_name(module_name: *const u16) -> Option<PVOID> {
    let peb: *mut PEB;
    unsafe {
        asm!(
            "mov {}, gs:[0x60]",
            out(reg) peb,
        );
        let ldr = (*peb).Ldr;
        let module_list = &((*ldr).InLoadOrderModuleList);

        // The first entry of LDR_DATA_TABLE_ENTRY is a LIST_ENTRY, so transmuting this address
        // from LIST_ENTRY to LDR_DATA_TABLE_ENTRY is legal.
        let mut cur_module: *const LDR_DATA_TABLE_ENTRY = core::mem::transmute(module_list);

        // The list is doubly-linked, so eventually we will wrap back around to the head.
        let module_list_head = cur_module;

        loop {
            let cur_name = (*cur_module).BaseDllName.Buffer;
            if !cur_name.is_null() && icmp_raw_str_u16(module_name, cur_name) {
                return Some((*cur_module).BaseAddress);
            }

            let flink = (*cur_module).InLoadOrderModuleList.Flink;
            cur_module = flink as *const LDR_DATA_TABLE_ENTRY;

            if cur_module == module_list_head {
                // We wrapped the whole list and didn't find a result.
                return None;
            }
        }
    }
}
```

Then [parse the PE's export table](https://github.com/exploits-forsale/solstice/blob/6c47b5a0cd155d629845412974e7580fa9dff840/crates/shellcode_utils/src/lib.rs#L121-L161) to find `GetModuleHandleA()`, and `GetProcAddress()`.

{% end %}

## The Easy Parts

[Although it's been talked about before](https://github.com/BenjaminSoelberg/ReflectivePELoader?tab=readme-ov-file), I'll give a brief overview of how a basic loader works:

1. Parse the PE headers and `VirtualAlloc()` some memory for the "cloned" PE with all the fixups applied. You'll try to `VirtualAlloc()` at the PE's preferred load address, but if you don't get it fall back to a random address. This is your _load address_. From here you calculate the delta between the preferred and actual load address and this will be used for fixing relocations. (Note: copying the PE just to change its fields isn't strictly necessary but simplifies some things)

2. [Iterate each PE section and copy it over to the newly `VirtualAlloc`'d region](https://github.com/exploits-forsale/solstice/blob/6c47b5a0cd155d629845412974e7580fa9dff840/crates/solstice_loader/src/pelib.rs#L211-L254). The virtual addresses here are _relative_ virtual addresses, so you just take each section's VirtualAddress, add it to the load address, and copy the section from its old location to the new address.

3. [Fix section permissions](https://github.com/exploits-forsale/solstice/blob/6c47b5a0cd155d629845412974e7580fa9dff840/crates/solstice_loader/src/pelib.rs#L256-L321). For each section, look at its `Characteristics` field and determine the correct permissions. `VirtualProtect()` the section according to the permissions.

4. [Fix imports](https://github.com/exploits-forsale/solstice/blob/6c47b5a0cd155d629845412974e7580fa9dff840/crates/solstice_loader/src/pelib.rs#L425-L545). For each import in the import table (`IMAGE_DIRECTORY_ENTRY_IMPORT`), ensure the imported DLL is loaded. Then use the loaded DLL's handle with `GetProcAddress()` to get the address of the function being imported. For each import in the table, write the real address in the import's thunk. Instead of `GetProcAddress()` could also parse the module's exports and match things up, but I took the lazy way.

5. [Fix relocations](https://github.com/exploits-forsale/solstice/blob/6c47b5a0cd155d629845412974e7580fa9dff840/crates/solstice_loader/src/pelib.rs#L323-L398). This basically involves walking the `IMAGE_DIRECTORY_ENTRY_BASERELOC` directory and fixing each `IMAGE_BASE_RELOCATION` such that you add the delta calculated in step 1 to the relocation's `VirtualAddress` field. There's some nuance here where you need to only modify certain bits, etc. etc. but this is the basic idea.

6. [Call the module's entrypoints](https://github.com/exploits-forsale/solstice/blob/main/crates/solstice_loader/src/lib.rs#L343-L347).

I learned through this experience that PEs can have multiple thread-local storage callbacks called before the actual module entrypoint. Calling these is fairly straightforward:

```rust
let tls_directory =
    &ntheader_ref.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_TLS as usize];

// Grab the TLS data from the PE we're loading
let tls_data_addr =
    baseptr.offset(tls_directory.VirtualAddress as isize) as *mut IMAGE_TLS_DIRECTORY64;

let tls_data: &mut IMAGE_TLS_DIRECTORY64 = unsafe { core::mem::transmute(tls_data_addr) };

let mut callbacks_addr = tls_data.AddressOfCallBacks as *const *const c_void;
if !callbacks_addr.is_null() {
    let mut callback = unsafe { *callbacks_addr };

    while !callback.is_null() {
        execute_tls_callback(baseptr, callback);
        callbacks_addr = callbacks_addr.add(1);
        callback = unsafe { *callbacks_addr };
    }
}

unsafe fn execute_tls_callback(baseptr: *const c_void, entrypoint: *const c_void) {
    let func: ImageTlsCallbackFn = core::mem::transmute(entrypoint);
    func(baseptr, DLL_THREAD_ATTACH, ptr::null_mut());
}
```

Executing the image entrypoint is pretty similar:

```rust
let entrypoint = (baseptr as usize
    + (*(ntheader as *const IMAGE_NT_HEADERS64))
        .OptionalHeader
        .AddressOfEntryPoint as usize) as *const c_void;

// Create a new thread to execute the image
execute_image(baseptr, entrypoint, context.fns.create_thread_fn);

unsafe fn execute_image(
    dll_base: *const c_void,
    entrypoint: *const c_void,
    create_thread_fn: CreateThreadFn,
) {
    let func: extern "system" fn(*const c_void, u32, *const c_void) -> u32 =
        core::mem::transmute(entrypoint);
    func(dll_base, DLL_PROCESS_ATTACH, ptr::null());
}
```

## The Hard Parts

There were some parts that really kicked my ass in figuring out, but in my opinion were very important for what I wanted in the PE loader.

1. The exploit / PE loader must not cause the hijacked application to become unreliable. I don't want to be debugging crashes in some of the existing threads that broke simply because we're hijacking the address space.

2. We must be able to run complex applications. Since we're using this technique to bypass code integrity, this will be our main method of running arbitrary applications.

3. The application shouldn't _know_ it's been reflectively loaded, or care.

### Thread-Local Storage

Related to #2, the absolute biggest challenge I faced was with applications that use thread-local storage (TLS). Having done all of my development in Rust, my test program that I was loading was also written in Rust.

I kept crashing on `int 29` instructions (`RtlFailFast(code)`) shortly after executing the module's entrypoint. This was **extremely** painful to debug but eventually I figured out that I was failing after fetching data from TLS

[![Screenshot of assembly instructions from a Rust "hello world" application loading data from TLS in IDA pro](/img/pe-loader/tls-thread-set-current.png)](/img/pe-loader/tls-thread-set-current.png)

[![Screenshot of assembly instructions from a Rust "hello world" application executing an `int 29` instruction in IDA pro](/img/pe-loader/int-29.png)](/img/pe-loader/int-29.png)

I was kind of confused because I didn't expect my application to use TLS, but apparently even the most basic "hello world" Rust program uses TLS:

[![Screenshot of a Rust "hello world" application loaded into the "PE Bear" program, showing its TLS directory](/img/pe-loader/pe-bear-tls.png)](/img/pe-loader/pe-bear-tls.png)

It turns out that this is related to Rust's thread initialization code that sets some thread-locals for the current thread and thread ID: [https://github.com/rust-lang/rust/blob/2e630267b2bce50af3258ce4817e377fa09c145b/library/std/src/thread/mod.rs#L694](https://github.com/rust-lang/rust/blob/2e630267b2bce50af3258ce4817e377fa09c145b/library/std/src/thread/mod.rs#L694)

So I came to realize that my original idea for how I was handling TLS data was completely flawed. Originally I was _allocating_ new memory for my module's TLS, but didn't even realize it had some default state associated with it that I had to copy over. Simple fix right?

```patch
diff --git a/crates/loader/src/lib.rs b/crates/loader/src/lib.rs
index 97311d0..d66773d 100755
--- a/crates/loader/src/lib.rs
+++ b/crates/loader/src/lib.rs
@@ -180,34 +185,53 @@ unsafe fn reflective_loader_impl(context: LoaderContext) {
             .OptionalHeader
             .AddressOfEntryPoint as usize) as *const c_void;

-    let tls_directory = &ntheader_ref.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_TLS];
+    let tls_directory =
+        &ntheader_ref.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_TLS as usize];
+
+    // Grab the TLS data from the PE we're loading
+    let tls_data_addr =
+        baseptr.offset(tls_directory.VirtualAddress as isize) as *mut IMAGE_TLS_DIRECTORY64;
+
+    // TODO: Patch the module list
+    let tls_index = patch_module_list(
+        context.image_name,
+        baseptr,
+        imagesize,
+        context.fns.get_module_handle_fn,
+        tls_data_addr,
+        context.fns.virtual_protect,
+        entrypoint,
+    );
+
     if tls_directory.Size > 0 {
         // Grab the TLS data from the PE we're loading
         let tls_data_addr =
             baseptr.offset(tls_directory.VirtualAddress as isize) as *mut IMAGE_TLS_DIRECTORY64;

-        let tls_data: &IMAGE_TLS_DIRECTORY64 = unsafe { core::mem::transmute(tls_data_addr) };
+        let tls_data: &mut IMAGE_TLS_DIRECTORY64 = unsafe { core::mem::transmute(tls_data_addr) };

         // Grab the TLS start from the TEB
         let tls_start: *mut *mut c_void;
         unsafe { core::arch::asm!("mov {}, gs:[0x58]", out(reg) tls_start) }

-        let tls_index = unsafe { *(tls_data.AddressOfIndex as *const u32) };
-
         let tls_slot = tls_start.offset(tls_index as isize);
         let raw_data_size = tls_data.EndAddressOfRawData - tls_data.StartAddressOfRawData;
-        *tls_slot = (context.fns.virtual_alloc)(
+        let tls_data_addr = (context.fns.virtual_alloc)(
             ptr::null(),
-            raw_data_size as usize,
+            raw_data_size as usize, // + tls_data.SizeOfZeroFill as usize,
             MEM_COMMIT,
             PAGE_READWRITE,
         );

-        // if !tls_start.is_null() {
-        //     // Zero out this memory
-        //     let tls_slots: &mut [u64] = unsafe { core::slice::from_raw_parts_mut(tls_start, 64) };
-        //     tls_slots.iter_mut().for_each(|slot| *slot = 0);
-        // }
+        core::ptr::copy_nonoverlapping(
+            tls_data.StartAddressOfRawData as *const _,
+            tls_data_addr,
+            raw_data_size as usize,
+        );
+
+        // Update the TLS index
+        core::ptr::write(tls_data.AddressOfIndex as *mut u32, tls_index);
+        *tls_slot = tls_data_addr;

         let mut callbacks_addr = tls_data.AddressOfCallBacks as *const *const c_void;
         if !callbacks_addr.is_null() {
```

This code worked, but not for long. I obviously had no idea how TLS worked, and soon discovered that in a multi-threaded application I was _again_ getting similar crashes because the TLS data was bad. Through much pain and debugging I ended up learning:

- Changing the TLS for your current thread is obviously not enough. New threads that spawn won't have the modifications I did above, so they'll have "default" TLS without my module included since the changes I did above are only reflected for the current thread. Duh.

- TLS is allocated in slots for the current thread and each slot is a pointer to the TLS data.

- Windows keeps a cache of TLS directories for each loaded module, which means you can't just pave over the hijacked module's TLS data with your new TLS data and things will "just work". You'll have to update the cache.

### Fixing TLS Data

In the above section I mentioned that Windows keeps a cache of TLS directories for each loaded module, and I think this is a critical reason why the reflective PE loaders I sampled didn't bother with TLS data ([only one loader sampled seemed to support TLS data](https://github.com/DarthTon/Blackbone/blob/5ede6ce50cd8ad34178bfa6cae05768ff6b3859b/src/BlackBone/ManualMap/Native/NtLoader.cpp#L153)).

I really only discovered this by painfully debugging and figuring out the application only crashed when spawning new threads, that the crashes were relating to data in TLS, and figuring that something must be wrong with the TLS data.

It finally clicked when I noticed that the `ThreadLocalStoragePointer` for the crashing thread's TEB didn't match the spawning thread's...

[![!teb command in WinDbg](/img/pe-loader/teb-command.png)](/img/pe-loader/teb-command.png)

[![Clicking the TEB pointer in WinDbg's !teb output](/img/pe-loader/thread-local-storage.png)](/img/pe-loader/thread-local-storage.png)

This is super obvious in hindsight! Each thread's TLS has to be unique, but I don't know... I thought the `ThreadLocalStoragePointer` was a pointer to the _default state_ TLS and the per-thread slots were in the TEB's `TlsSlots` field?

Anyways, I set a breakpoint at the thread initialization routine, `LdrpInitializeThread`, and debugged it to see if there was anything that stood out for TLS initialization. Like magic, I eventually stepped into `LdrpAllocateTls`:

[![WinDbg stack for a new user thread showing the call into LdrpAllocateTls](/img/pe-loader/LdrpAllocateTls.png)](/img/pe-loader/LdrpAllocateTls.png)

The [ReactOS source code](https://github.com/mirror/reactos/blob/c6d2b35ffc91e09f50dfb214ea58237509329d6b/reactos/dll/ntdll/ldr/ldrinit.c#L1215-L1273) was of huge help here in figuring out what was going on, but essentially what happens when spawning a new thread is:

1. If any of the currently loaded modules has TLS, allocate a `ThreadLocalStoragePointer`.
2. The size of this memory block is `sizeof(void*) * NUM_MODULES_WITH_TLS_DATA`.
3. Iterate some `TlsLinks` list. This is a list of `LDRP_TLS_DATA`:

```c
typedef struct _LDRP_TLS_DATA
{
    LIST_ENTRY TlsLinks;
    IMAGE_TLS_DIRECTORY TlsDirectory;
} LDRP_TLS_DATA, *PLDRP_TLS_DATA;
```

4. Calculate the size of the TLS data based on the `TlsDirectory`, and copy its contents.
5. Put the pointer to the memory allocated in step 4 in the appropriate slot, recorded as `TlsData->TlsDirectory.Characteristics`.

Now that I know the TLS data is cached, can't I just overwrite the `TlsDirectory` data in this list from the host module with the data from the new module? Well yes... and no. The `LDRP_TLS_DATA` is heap-allocated, so I'd have to scan the heap which would be pretty bug-prone.

#### Janky Approach to Fixing TLS Data

**tl;dr**: use a private `ntdll` function that returns the cached `TLS_ENTRY` from a `LDR_DATA_TABLE_ENTRY*` to find the hijacked module's TLS data. Once found, overwrite the cached `IMAGE_TLS_DIRECTORY` with the new module's.

This has a big problem: if the program you're loading requires TLS, you must inject into a program with TLS. Otherwise you'll be replacing a random DLL's TLS data if you aren't careful.

{% collapse(preview="List Patching Details") %}

I popped `ntdll.dll` into IDA to see what functions were using this `LdrpTlsList` to see if maybe there was some other way I could grab the list's address.

[![IDA Pro window showing functions using LdrpTlsList](/img/pe-loader/LdrpFindTlsEntry.png)](/img/pe-loader/LdrpFindTlsEntry.png)

I found that in Windows (but not ReactOS) is a function, "`LdrpFindTlsList`", which will return a `PTLS_ENTRY` (the actual name of the Windows data structure for ReactOS's `LDRP_TLS_DATA`) given a `PLDR_DATA_TABLE_ENTRY`. [Ken Johnson even conviently provided the source code on his blog](http://www.nynaeve.net/Code/VistaImplicitTls.cpp).

The `PLDR_DATA_TABLE_ENTRY` can be found in the PEB which you can explore using the `!peb` command in WinDbg.

The complete code:

```rust
/// Returns the Thread Environment Block (TEB)
pub fn teb() -> *mut TEB {
    let mut teb: *mut TEB;
    unsafe { core::arch::asm!("mov {}, gs:[0x30]", out(reg) teb) }

    teb
}

pub unsafe fn patch_module_list(
    image_name: Option<&[u16]>,
    new_base_address: *mut c_void,
    module_size: usize,
    get_module_handle_fn: GetModuleHandleAFn,
    this_tls_data: *const IMAGE_TLS_DIRECTORY64,
    virtual_protect: VirtualProtectFn,
    entrypoint: *const c_void,
) -> u32 {
    let current_module = get_module_handle_fn(core::ptr::null());

    let teb = teb();
    let peb = (*teb).ProcessEnvironmentBlock;
    let ldr_data = (*peb).Ldr;
    let module_list_head = &mut (*ldr_data).InMemoryOrderModuleList as *mut LIST_ENTRY;
    let mut next = (*module_list_head).Flink;
    while next != module_list_head {
        // -1 because this is the second field in the LDR_DATA_TABLE_ENTRY struct.
        // the first one is also a LIST_ENTRY
        let module_info = (next.offset(-1)) as *mut LDR_DATA_TABLE_ENTRY;
        if (*module_info).DllBase == current_module {
            (*module_info).DllBase = new_base_address;
            // EntryPoint
            (*module_info).Reserved3[0] = entrypoint as *mut c_void;
            // SizeOfImage
            (*module_info).Reserved3[1] = module_size as *mut c_void;

            if !this_tls_data.is_null() {
                let ntdll_addr = get_module_handle_fn("ntdll.dll\0".as_ptr() as *const _);
                if let Some(ntdll_text) = get_module_section(ntdll_addr as *mut _, b".text") {
                    for window in ntdll_text.windows(LDRP_FIND_TLS_ENTRY_SIGNATURE_BYTES.len()) {
                        if window == LDRP_FIND_TLS_ENTRY_SIGNATURE_BYTES {
                            // Get this window's pointer and move backwards to find the start of the fn
                            let mut ptr = window.as_ptr();
                            loop {
                                let behind = ptr.offset(-1);
                                if *behind == 0xcc {
                                    break;
                                }
                                ptr = ptr.offset(-1);
                            }

                            let LdrpFindTlsEntry: LdrpFindTlSEntryFn = core::mem::transmute(ptr);

                            let list_entry = LdrpFindTlsEntry(module_info);

                            (*list_entry).TlsDirectory = *this_tls_data;
                        }
                    }
                }
            }
            break;
        }
        next = (*next).Flink;
    }

    // This stuff here is mostly unnecessary, but I did it anyways as a "just in case".
    // The idea is to overwrite the `IMAGE_TLS_DIRECTORY` of the hijacked module
    // to point at the new module's.
    // And to get the hijacked module's TLS index since that's the slot we'll be
    // hijacking for our new module.
    if !this_tls_data.is_null() {
        let dosheader = get_dos_header(current_module);
        let ntheader = get_nt_header(current_module, dosheader);

        #[cfg(target_arch = "x86_64")]
        let ntheader_ref: &mut IMAGE_NT_HEADERS64 = unsafe { core::mem::transmute(ntheader) };
        #[cfg(target_arch = "x86")]
        let ntheader_ref: &mut IMAGE_NT_HEADERS32 = unsafe { core::mem::transmute(ntheader) };

        let real_module_tls_entry =
            &mut ntheader_ref.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_TLS as usize];

        let real_module_tls_dir = current_module
            .offset(real_module_tls_entry.VirtualAddress as isize)
            as *mut IMAGE_TLS_DIRECTORY64;

        let mut old_perms = 0;
        virtual_protect(
            real_module_tls_dir as *mut _ as *const _,
            core::mem::size_of::<IMAGE_TLS_DIRECTORY64>(),
            PAGE_READWRITE,
            &mut old_perms,
        );

        let idx = *((*real_module_tls_dir).AddressOfIndex as *const u32);
        *real_module_tls_dir = *this_tls_data;

        idx
    } else {
        0
    }
}
```

{% end %}

#### The Good Method

Remember how I said [only one loader sampled seemed to support TLS data](https://github.com/DarthTon/Blackbone/blob/5ede6ce50cd8ad34178bfa6cae05768ff6b3859b/src/BlackBone/ManualMap/Native/NtLoader.cpp#L153)? This happens to be the same approach they took.

Building on the above list patching method, I saw a different function called `LdrpAllocateTlsEntry` referenced the `LdrpTlsList` cache and is called by `LdrpHandleTlsData`. The latter function is called when a new module is loaded and is responsible for setting up almost all of the state relating to a module's TLS.

It has no sanity checks on whether or not the module's TLS data has already been handled. Which is awesome, and actually makes sense! Why sanity check if this function is only ever called once during real loader scenarios?

We can abuse this by performing the following operations:

1. Update the hijacked module's `LDR_DATA_TABLE_ENTRY` (found via the PEB) to point to our new module's base address.
2. Release the hijacked module's TLS data (`LdrpReleaseTlsEntry`)
3. Call `LdrpHandleTlsData` with the hijacked module to force the new TLS data to be loaded.

This also solves all of the problems we had with both prior methods!

- We can inject into any process and not just processes that have TLS data
- According to the [Ken Johnson code](http://www.nynaeve.net/Code/VistaImplicitTls.cpp) this function updates the TLS info in the PEB (or maybe some kernel data?)
- And according to the Ken Johnson code updates other threads
- Is less code than _both_ other solutions
- Doesn't require me to manually update the new module's TLS index

```rust
const LDRP_RELEASE_TLS_ENTRY_SIGNATURE_BYTES: [u8; 7] = [0x83, 0xE1, 0x07, 0x48, 0xC1, 0xEA, 0x03];

const LDRP_HANDLE_TLS_DATA_SIGNATURE_BYTES: [u8; 9] =
    [0xBA, 0x23, 0x00, 0x00, 0x00, 0x48, 0x83, 0xC9, 0xFF];


// Function signature/type alias for LdrpReleaseTlsEntry
type LdrpReleaseTlsEntryFn =
    unsafe extern "system" fn(entry: *mut LDR_DATA_TABLE_ENTRY, unk: *mut c_void) -> NTSTATUS;

// Function signature/type alias for LdrpHandleTlsData
type LdrpHandleTlsDataFn = unsafe extern "system" fn(entry: *mut LDR_DATA_TABLE_ENTRY);

/// Returns the Thread Environment Block (TEB)
pub fn teb() -> *mut TEB {
    let mut teb: *mut TEB;
    unsafe { core::arch::asm!("mov {}, gs:[0x30]", out(reg) teb) }

    teb
}

/// Patches the module list to change the hijacked module's DLL base and entrypoint.
///
/// TODO: Patch image name.
///
/// This is useful to ensure that a program that depends on `GetModuleHandle*`
/// doesn't fail simply because its module is not found
pub unsafe fn patch_ldr_data(
    new_base_address: *mut c_void,
    module_size: usize,
    get_module_handle_fn: GetModuleHandleAFn,
    this_tls_data: *const IMAGE_TLS_DIRECTORY64,
    entrypoint: *const c_void,
) {
    let current_module = get_module_handle_fn(core::ptr::null());

    let teb = teb();
    let peb = (*teb).ProcessEnvironmentBlock;
    let ldr_data = (*peb).Ldr;
    let module_list_head = &mut (*ldr_data).InMemoryOrderModuleList as *mut LIST_ENTRY;
    let mut next = (*module_list_head).Flink;

    while next != module_list_head {
        // -1 because this is the second field in the LDR_DATA_TABLE_ENTRY struct.
        // the first one is also a LIST_ENTRY
        let module_info = (next.offset(-1)) as *mut LDR_DATA_TABLE_ENTRY;
        if (*module_info).DllBase != current_module {
            next = (*next).Flink;
            continue;
        }

        (*module_info).DllBase = new_base_address;
        // EntryPoint
        (*module_info).Reserved3[0] = entrypoint as *mut c_void;
        // SizeOfImage
        (*module_info).Reserved3[1] = module_size as *mut c_void;

        if this_tls_data.is_null() {
            break;
        }

        let ntdll_addr = get_module_handle_fn("ntdll.dll\0".as_ptr() as *const _);
        let ntdll_text = get_module_section(ntdll_addr as *mut _, b".text");
        if ntdll_text.is_none() {
            break;
        }

        let ntdll_text = ntdll_text.unwrap();
        // Get the TLS entry for the current module and remove it from the list
        if let Some(window) = ntdll_text
            .windows(LDRP_RELEASE_TLS_ENTRY_SIGNATURE_BYTES.len())
            .find(|&window| window == LDRP_RELEASE_TLS_ENTRY_SIGNATURE_BYTES)
        {
            // Get this window's pointer. It will land us in the middle of this function though
            let mut ptr = window.as_ptr();
            // Walk backwards until we find the prologue. Pray this function retains padding
            loop {
                if *ptr.offset(-1) == 0xcc && *ptr.offset(-2) == 0xcc {
                    break;
                }
                ptr = ptr.offset(-1);
            }

            #[allow(non_snake_case)]
            let LdrpReleaseTlsEntry: LdrpReleaseTlsEntryFn = core::mem::transmute(ptr);

            LdrpReleaseTlsEntry(module_info, core::ptr::null_mut());
        }

        if let Some(window) = ntdll_text
            .windows(LDRP_HANDLE_TLS_DATA_SIGNATURE_BYTES.len())
            .find(|&window| window == LDRP_HANDLE_TLS_DATA_SIGNATURE_BYTES)
        {
            // Get this window's pointer. It will land us in the middle of this function though
            let mut ptr = window.as_ptr();
            // Walk backwards until we find the prologue. Pray this function retains padding
            loop {
                if *ptr.offset(-1) == 0xcc && *ptr.offset(-2) == 0xcc {
                    break;
                }
                ptr = ptr.offset(-1);
            }

            #[allow(non_snake_case)]
            let LdrpHandleTlsData: LdrpHandleTlsDataFn = core::mem::transmute(ptr);

            LdrpHandleTlsData(module_info);
        }
        break;
    }
}
```

### Patching Command-Line Args

This has been done by other PE loaders, but I wanted to call this out as well: while the PEB contains the image name and process arugments, so does `kernelbase.dll`! Why? For `GetCommandLineW` and `GetCommandLineA` of course.

This one wasn't _too_ bad to patch so long as you want to rely on the fact that the `UNICODE_STRING` structure for the PEB and in `kernelbase.dll` share the same backing buffer (i.e. the latter is a shallow copy of the former). That also doesn't account for the `ANSI_STRING` variant... but 🤷‍♂️

tl;dr of the following code: we scan the global memory of `kernelbase.dll` looking for the previously mentioned `UNICODE_STRING` buffer pointer we obtained from the PEB then, once found, update its pointer and length to match our new pointer and length.

```rust
pub unsafe fn patch_cli_args(args: Option<&[u16]>, kernelbase_ptr: *mut u8) {
    if let Some(args) = args {
        let peb = (*teb()).ProcessEnvironmentBlock;
        // This buffer pointer should match the cached UNICODE_STRING in kernelbase
        let buffer = (*(*peb).ProcessParameters).CommandLine.Buffer;

        // Search this pointer in kernel32's .data section
        if let Some(kernelbase_data) = get_module_section(kernelbase_ptr, b".data") {
            let ptr = kernelbase_data.as_mut_ptr();
            let len = kernelbase_data.len() / 2;
            // Do not have two mutable references to the same memory range

            let data_as_wordsize = core::slice::from_raw_parts(ptr as *const usize, len);
            if let Some(found) = data_as_wordsize
                .iter()
                .position(|ptr| *ptr == buffer as usize)
            {
                // We originally found this while scanning usize-sized data, so we have to translate
                // this to a byte index
                let found_buffer_byte_pos = found * core::mem::size_of::<usize>();
                // Get the start of the unicode string
                let unicode_str_start =
                    found_buffer_byte_pos - core::mem::offset_of!(UNICODE_STRING, Buffer);
                let unicode_str = core::mem::transmute::<_, &mut UNICODE_STRING>(
                    ptr.offset(unicode_str_start as isize),
                );

                let args_byte_len = args.len() * core::mem::size_of::<u16>();
                unicode_str.Buffer = args.as_ptr() as *mut _;
                unicode_str.Length = args_byte_len as u16;
                unicode_str.MaximumLength = args_byte_len as u16;
            }
        }
    }
}
```

### Preventing Hijacked Application Crashes

I thought a great idea to prevent the hijacked application from crashing by suspending all of its threads. I was surprised to learn that not only was this fairly easy to do on Windows, it was _even_ easier to accidentally do this from a non-admin session for all other Medium-IL processes!

[![Tweet by @landaire with text, "it has been 0 minutes since I last accidentally suspended all medium-IL threads on my system"](/img/pe-loader/thread_suspension.png)](/img/pe-loader/thread_suspension.png)

_Yeah, don't call `CreateToolhelp32Snapshot()` incorrectly_.

The Windows examples were fairly straightforward but on Xbox the code crashed. And that's because the `kernel32_ptr` here actually needs to be a pointer to `kernel32legacy.dll` since on Xbox `kernel32.dll` doesn't exist.

That took me a while to figure out and hunt down and double-check where the functions got relocated to.

Here is the code I eventually came up with:

```rust
pub unsafe fn suspend_threads(kernel32_ptr: PVOID, kernelbase_ptr: PVOID) {
    // kernel32legacy.dll on xbox
    let CreateToolhelp32Snapshot = fetch_create_tool_help32(kernel32_ptr);
    let Thread32Next = fetch_thread_32_next(kernel32_ptr);
    let Thread32First = fetch_thread_32_first(kernel32_ptr);

    // kernelbase.dll on xbox
    let GetCurrentThreadId = fetch_get_current_thread_id(kernelbase_ptr);
    let GetCurrentProcessId = fetch_get_current_process_id(kernelbase_ptr);
    let OpenThread = fetch_open_thread(kernelbase_ptr);
    let SuspendThread = fetch_suspend_thread(kernelbase_ptr);
    let CloseHandle = fetch_close_handle(kernelbase_ptr);

    let pid = GetCurrentProcessId();
    // Suspend all other threads except this one
    let h = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, pid);
    let current_thread = GetCurrentThreadId();
    let mut te: THREADENTRY32 = core::mem::zeroed();
    te.dwSize = core::mem::size_of_val(&te) as u32;
    if Thread32First(h, &mut te as *mut _) != 0 {
        loop {
            if te.dwSize as usize
                >= offset_of!(THREADENTRY32, th32OwnerProcessID)
                    + core::mem::size_of_val(&te.th32OwnerProcessID)
                && te.th32OwnerProcessID == pid
                && current_thread != te.th32ThreadID
            {
                let thread_handle = OpenThread(THREAD_SUSPEND_RESUME, false, te.th32ThreadID);
                SuspendThread(thread_handle);
            }
            if Thread32Next(h, &mut te as *mut _) == 0 {
                break;
            }
            te.dwSize = core::mem::size_of_val(&te) as u32;
        }
    }

    CloseHandle(h);
}
```

## TODO

There are still some remaining items for the loader:

- Ensure that `GetModuleHandle(NULL)` (handle to self) works correctly.
- Maybe load .NET binaries? We already have a technique for launching .NET code, but having an all-in-one solution might be nice.
- Maybe make this a generic crate?

## fin

This was a fun exercise that taught me a lot about how Windows binaries are loaded. I'd like to thank carrot_c4k3, tuxuser, and 0e9ca321209eca529d6988c276e4e4ed for their help/support.

With this work, we're now able to do cool things on Xbox!

For example, using the PE loader we can launch the main GameScript exploit, launch Emma's Windows exploit binary to elevate privileges, spawn a new process as suspended, inject our shellcode/PE loader, and execute a custom SSH/SFTP daemon which uses tokio for async. I think I accomplished my goal of loading complex applications :\)

{{ video(path="/img/pe-loader/xbox_hacks.mp4") }}

*The top terminal session is the payload server running on my PC, while the bottom netcat session is the output from the exploit and SSH daemon running on my Xbox.*

tuxuser even managed to get toasts working!

[![Collateral Damage Executed Achievement](/img/pe-loader/collat_achievement.webp)](/img/pe-loader/collat_achievement.webp)
