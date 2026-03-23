# Post-Mortem: Lesson 7 — Scan Matching Localization Setup

> **Scope:** This document covers every infrastructure and toolchain issue encountered when running the Udacity Scan Matching Localization project starter code on a **local Ubuntu 25.10** machine with an **NVIDIA RTX 5070** GPU. None of these issues are related to the NDT algorithm implementation itself.


- [Post-Mortem: Lesson 7 — Scan Matching Localization Setup](#post-mortem-lesson-7--scan-matching-localization-setup)
  - [Summary Table](#summary-table)
  - [Issue 1 — C++14 vs PCL 1.15](#issue-1--c14-vs-pcl-115)
    - [What happened](#what-happened)
    - [Root cause](#root-cause)
    - [Fix](#fix)
  - [Issue 2 — CARLA Library Version Mismatch (The Big One)](#issue-2--carla-library-version-mismatch-the-big-one)
    - [What happened](#what-happened-1)
    - [Root cause](#root-cause-1)
    - [Investigation](#investigation)
    - [Fix: Rebuilding `libcarla_client.a` from CARLA 0.9.16 source](#fix-rebuilding-libcarla_clienta-from-carla-0916-source)
      - [Patch 2a — `ThreadPool.h`: deprecated `io_context::work`](#patch-2a--threadpoolh-deprecated-io_contextwork)
      - [Patch 2b — `EndPoint.h`: deprecated resolver `::query` / `::iterator`](#patch-2b--endpointh-deprecated-resolver-query--iterator)
      - [Patch 2c — `FileSystem.cpp`: incomplete Boost.Filesystem include](#patch-2c--filesystemcpp-incomplete-boostfilesystem-include)
      - [Patch 2d — Missing `carla/Version.h`](#patch-2d--missing-carlaversionh)
      - [Patch 2e — Missing Recast/Detour headers](#patch-2e--missing-recastdetour-headers)
      - [Patch 2f — TrafficManager (16 files, complex dependency tree)](#patch-2f--trafficmanager-16-files-complex-dependency-tree)
      - [Patch 2g — Duplicate `Map.o` object name](#patch-2g--duplicate-mapo-object-name)
      - [Result](#result)
  - [Issue 3 — `LidarMeasurement` Detection API Change](#issue-3--lidarmeasurement-detection-api-change)
    - [What happened](#what-happened-2)
    - [Root cause](#root-cause-2)
    - [Fix](#fix-1)
  - [Issue 4 — CARLA Crashes on `-opengl` (NVIDIA PRIME)](#issue-4--carla-crashes-on--opengl-nvidia-prime)
    - [What happened](#what-happened-3)
    - [Root cause](#root-cause-3)
    - [Diagnosis](#diagnosis)
    - [Fix](#fix-2)
  - [Issue 5 — Spawn Collision on Restart](#issue-5--spawn-collision-on-restart)
    - [What happened](#what-happened-4)
    - [Root cause](#root-cause-4)
    - [Investigation detour](#investigation-detour)
    - [Fix](#fix-3)
  - [Issue 6 — SIGSEGV in UCX Shared-Memory Transport (Ubuntu 25.10)](#issue-6--sigsegv-in-ucx-shared-memory-transport-ubuntu-2510)
    - [What happened](#what-happened-5)
    - [Root cause](#root-cause-5)
    - [Investigation](#investigation-1)
    - [Fix](#fix-4)
  - [Issue 7 — Two `cloud_loc` Binaries (Stale Root Binary)](#issue-7--two-cloud_loc-binaries-stale-root-binary)
    - [What happened](#what-happened-6)
    - [Root cause](#root-cause-6)
    - [Fix](#fix-5)
  - [Lessons Learned](#lessons-learned)


---

## Summary Table

| # | Issue | Root Cause | Effort |
|---|---|---|---|
| 1 | Build: C++14 vs PCL 1.15 | `CMakeLists.txt` standard mismatch | 5 min |
| 2 | CARLA version mismatch (0.9.9.4 lib vs 0.9.16 sim) | Git LFS contained wrong prebuilt library | ~4 hours |
| 3 | `LidarMeasurement` API change | Struct layout changed between 0.9.9.x and 0.9.16 | 15 min |
| 4 | CARLA `-opengl` crashes immediately | NVIDIA PRIME: Mesa selected instead of NVIDIA | 30 min |
| 5 | Spawn collision on restart | Stale vehicle actor in CARLA world | 20 min |
| 6 | UCX SIGSEGV on Ubuntu 25.10 | `mmap()` permission rejected by glibc 2.42 kernel | ~2 hours |
| 7 | Stale binary in project root | Two cmake invocation styles produce different paths | 10 min |

---

## Issue 1 — C++14 vs PCL 1.15

### What happened
`cmake --build` failed immediately:
```
error: 'index_sequence' is not a member of 'std'
error: 'make_index_sequence' is not a member of 'std'
```

### Root cause
The original `CMakeLists.txt` declared:
```cmake
set(CMAKE_CXX_STANDARD 14)
```
PCL 1.12 switched several internal headers to use C++17 features (`std::index_sequence`, structured bindings). The system PCL was 1.15.

### Fix
Changed `CMakeLists.txt`:
```cmake
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
```
Also removed the redundant `-std=c++14` from `add_definitions` and switched to `add_compile_options(-O3)`.

---

## Issue 2 — CARLA Library Version Mismatch (The Big One)

### What happened
Running `./cloud_loc` against the bundled CARLA 0.9.16 simulator produced:
```
WARNING: Version mismatch detected:
  Client API version = 0.9.9.4
  Simulator API version = 0.9.16
[Segmentation fault: address not mapped to object]
```

### Root cause
The repository's Git LFS stored a prebuilt `libcarla_client.a` (and associated headers) for CARLA **0.9.9.4** — the version used in the Udacity cloud workspace. However, the CARLA simulator binary bundled in `../CARLA/` is version **0.9.16**. The client library and simulator communicate via msgpack-rpc; the wire format changed substantially between these versions, causing a segfault on the first API call after the handshake.

### Investigation
Confirmed by checking:
```bash
strings libcarla-install/lib/libcarla_client.a | grep "0\.9\."
# → 0.9.9.4

../CARLA/CarlaUE4/Binaries/Linux/CarlaUE4-Linux-Shipping --version
# → 4.26.2-0+++UE4+Release-4.26  (CARLA 0.9.16)
```

### Fix: Rebuilding `libcarla_client.a` from CARLA 0.9.16 source

Sparse-cloned just `LibCarla/source` from the CARLA 0.9.16 GitHub tag, then compiled the client library with the system toolchain. This required **seven separate patches** to the CARLA source tree, all caused by the library having been written for Ubuntu 20.04 + Boost 1.72, while the local system has Ubuntu 25.10 + Boost 1.88:

#### Patch 2a — `ThreadPool.h`: deprecated `io_context::work`
`boost::asio::io_context::work` was removed in Boost 1.74. Replacement:
```cpp
// Before (CARLA original):
std::unique_ptr<boost::asio::io_context::work> _work;
_work = std::make_unique<boost::asio::io_context::work>(_io_context);

// After:
boost::asio::executor_work_guard<boost::asio::io_context::executor_type> _work;
_work = boost::asio::make_work_guard(_io_context);
```

#### Patch 2b — `EndPoint.h`: deprecated resolver `::query` / `::iterator`
The old ASIO resolver API was removed in Boost 1.73:
```cpp
// Before:
boost::asio::ip::tcp::resolver::query query(host, port);
auto it = resolver.resolve(query);
// use it->endpoint()

// After:
auto results = resolver.resolve(host, port);
// use results->endpoint()
```

#### Patch 2c — `FileSystem.cpp`: incomplete Boost.Filesystem include
```cpp
// Before:
#include <boost/filesystem/operations.hpp>

// After:
#include <boost/filesystem.hpp>
```

#### Patch 2d — Missing `carla/Version.h`
CARLA's build system generates this file from a template. It was not in the sparse clone:
```cpp
// Created manually:
namespace carla { inline const char* version() { return "0.9.16"; } }
```

#### Patch 2e — Missing Recast/Detour headers
`nav/Navigation.cpp` and `client/detail/WalkerNavigation.cpp` include Recast navigation headers that are not part of the LibCarla source tree (they live in `Unreal/CarlaUE4/Plugins/`). Created stub headers with forward declarations only, and replaced the full implementation files with empty stubs — navigation is not needed for the localization project.

#### Patch 2f — TrafficManager (16 files, complex dependency tree)
TrafficManager pulls in 16 source files with circular dependencies and additional Boost/Unreal includes. Created `TrafficManager_stub.cpp` with empty method bodies and static member definitions. Only the `InMemoryMap::Cook` method required a non-trivial stub signature.

#### Patch 2g — Duplicate `Map.o` object name
`carla/client/Map.cpp` and `carla/road/Map.cpp` both compile to `Map.o`. The linker silently drops one. Fixed by using directory-derived unique object file names in the build script:
```bash
# client/Map.cpp → client_Map.o
# road/Map.cpp   → road_Map.o
```

#### Result
Successfully built `libcarla_client.a` (6.3 MB). Also built:
- `librpc.a` from the bundled rpclib source
- Copied system Boost static libs (`libboost_filesystem.a`, `libboost_system.a`, `libboost_program_options.a`)
- Created empty stub archives for Recast/Detour so the linker is satisfied

---

## Issue 3 — `LidarMeasurement` Detection API Change

### What happened
After rebuilding with the 0.9.16 library, the lidar callback compiled but produced all-zero point positions, causing the NDT matcher to fail immediately.

### Root cause
Between CARLA 0.9.9.x and 0.9.16, the `LidarDetection` struct layout changed:

```cpp
// CARLA 0.9.9.x:
struct LidarDetection {
    float x, y, z;      // direct members
    float intensity;
};

// CARLA 0.9.16:
struct LidarDetection {
    geom::Location point;  // nested struct: .point.x, .point.y, .point.z
    float intensity;
};
```

### Fix
Updated the lidar callback in `c3-main.cpp`:
```cpp
// Before:
float dx = detection.x, dy = detection.y, dz = detection.z;

// After (0.9.16):
float dx = detection.point.x, dy = detection.point.y, dz = detection.point.z;
```

> **Udacity workspace warning:** The Udacity grader uses CARLA 0.9.9.4. If submitting to the Udacity platform, revert this change back to `detection.x`.

---

## Issue 4 — CARLA Crashes on `-opengl` (NVIDIA PRIME)

### What happened
```
4.26.2-0+++UE4+Release-4.26 522 0
Disabling core dumps.
Signal 11 (Segmentation fault)
[double RequestExitWithStatus]
```
CARLA exited within 1–2 seconds of launch.

### Root cause
The system uses NVIDIA PRIME on-demand GPU switching. By default, GLX applications use the Intel Mesa software renderer. CARLA's UE4 4.26 OpenGL renderer cannot initialise on Mesa and crashes.

### Diagnosis
```bash
glxinfo | grep vendor
# server glx vendor string: SGI
# client glx vendor string: Mesa Project and SGI   ← software renderer
```

### Fix
Switched from `-opengl` to `-vulkan` (which correctly routes through the NVIDIA ICD) and added PRIME offload environment variables:
```bash
__NV_PRIME_RENDER_OFFLOAD=1 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json \
./CarlaUE4.sh -vulkan -quality-level=Low -nosound
```
Also added `-quality-level=Low -nosound` to reduce startup time and GPU memory pressure.

---

## Issue 5 — Spawn Collision on Restart

### What happened
After any crash or forced kill of `cloud_loc`, the next run immediately died:
```
terminate called after throwing an instance of 'std::runtime_error'
  what():  Spawn failed because of collision at spawn position
[Aborted (core dumped)]
```

### Root cause
When `cloud_loc` is killed without a clean shutdown, CARLA does not automatically destroy the ego vehicle actor. The spawn point remains occupied. The original code used a hard-coded spawn index:
```cpp
auto transform = map->GetRecommendedSpawnPoints()[1];
auto ego_actor = world.SpawnActor((*vehicles)[12], transform);
```
`SpawnActor` throws `std::runtime_error` on collision rather than returning null.

### Investigation detour
The crash was initially misdiagnosed as a static-initialisation issue because the debug `std::cerr` prints were not appearing in the output. Investigation revealed that the **stale `cloud_loc` binary** in the project root was being executed instead of the freshly rebuilt one in `build/` (see Issue 7).

### Fix
Replaced with a loop using `TrySpawnActor` (returns `nullptr` on collision instead of throwing) across all available spawn points:
```cpp
auto spawnPoints = map->GetRecommendedSpawnPoints();
boost::shared_ptr<cc::Actor> ego_actor;
for (size_t sp = 0; sp < spawnPoints.size() && !ego_actor; ++sp)
    ego_actor = world.TrySpawnActor((*vehicles)[12], spawnPoints[sp]);
if (!ego_actor) { std::cerr << "ERROR: no free spawn point\n"; return 1; }
```
Town10HD_Opt has 155 spawn points, so there is always a free one.

---

## Issue 6 — SIGSEGV in UCX Shared-Memory Transport (Ubuntu 25.10)

### What happened
`cloud_loc` ran successfully for ~57 seconds, then crashed when the first lidar scan was delivered:
```
[ubuntu:PID:0:THREAD] Caught signal 11
  (Segmentation fault: invalid permissions for mapped object at address 0x740f3c02e000)
==== backtrace ====
 0  /lib/x86_64-linux-gnu/libucs.so.0(ucs_handle_error+0x2e4)
 1  /lib/x86_64-linux-gnu/libucs.so.0(+0x3209c)
 ...
 4  ./cloud_loc(+0x4c305)   ← CARLA streaming receive handler
```

### Root cause
CARLA 0.9.16 uses **OpenUCX** (`libucs.so`) for low-latency sensor data streaming between the simulator and client. UCX's default transport stack on Linux includes shared-memory transports (`posix`, `cma`, `knem`). These transports use `mmap()` with `PROT_EXEC` or custom protection flags.

Ubuntu 25.10 ships **glibc 2.42** and **kernel 6.11+**, which enforces stricter memory-protection policies. The `mmap()` call in UCX's shared-memory transport returns `EACCES` (permission denied) for the requested protection flags. Instead of handling the error gracefully, UCX dereferences the failed mapping, producing SIGSEGV.

CARLA 0.9.16 was developed and tested against **Ubuntu 20.04 / glibc 2.31 / kernel 5.15**, where these `mmap()` calls succeed.

### Investigation
Confirmed by checking the UCX transport in use:
```bash
UCX_LOG_LEVEL=debug ./cloud_loc 2>&1 | grep "UCX\|transport\|posix"
```
Output showed `posix` shared-memory transport being selected, failing on the first `mmap` call with a protection error.

### Fix
Force UCX to use TCP transport only (slightly higher latency, fully kernel-agnostic):
```bash
UCX_TLS=tcp UCX_POSIX_USE_PROC_LINK=n ./cloud_loc
```

With `UCX_TLS=tcp`:
- `cloud_loc` runs stably for 75+ seconds (the full test window)
- CARLA streams lidar data over localhost TCP sockets instead of shared memory
- No performance impact noticeable for this use case (local loopback)

This is set in `run_cloud_loc.sh` and also exported by `run_carla.sh`.

---

## Issue 7 — Two `cloud_loc` Binaries (Stale Root Binary)

### What happened
Code changes (including debug `std::cerr` prints) had no effect. The binary in the project root was not updated after `cmake --build build`.

### Root cause
Two cmake invocation styles produce different output locations:
- `cmake . && make` (legacy in-source) → binary in project root
- `cmake -S . -B build && cmake --build build` (out-of-source) → binary in `build/`

The project root contained an old binary from a previous in-source build. The test scripts ran `./cloud_loc` (root), not `./build/cloud_loc`.

### Fix
Added to `CMakeLists.txt`:
```cmake
set_target_properties(cloud_loc PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR})
```
Both build styles now place `cloud_loc` in the project root.

---

## Lessons Learned

1. **Check library ABI versions before anything else.** The 4-hour sinkhole of rebuilding libcarla could have been shorter if the version mismatch was caught before starting on the implementation.

2. **Ubuntu LTS ≠ Ubuntu rolling release.** CARLA was built for Ubuntu 20.04/22.04. Running it on Ubuntu 25.10 (glibc 2.42, kernel 6.11) exposes subtle binary-level incompatibilities that are not obvious from API changes alone.

3. **UCX environment variables are your friend.** Any time you see `libucs.so` in a backtrace on a modern Linux kernel, try `UCX_TLS=tcp` first before diving into kernel patches.

4. **`TrySpawnActor` over `SpawnActor`.** In any long-running CARLA test loop, always use the non-throwing variant and iterate over spawn points. Hard-coded indices break after the first crash.

5. **PRIME offload must be explicit.** On hybrid GPU systems, CARLA (and any Vulkan/OpenGL app) needs explicit `__NV_PRIME_RENDER_OFFLOAD=1` and `VK_ICD_FILENAMES` to use the discrete GPU. Without it, Mesa is selected silently and the app crashes with a cryptic signal 11.

6. **Debug binary identity first.** When `std::cerr` debug prints don't appear, verify *which binary is actually running* before assuming the crash is in static initialisation or a background thread.
