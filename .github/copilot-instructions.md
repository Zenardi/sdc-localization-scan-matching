# Copilot Instructions

## Repository Overview

Udacity Self-Driving Car Nanodegree (nd0013_cd2693) — Localization and Scan Matching. C++ exercises and a capstone project teaching ICP/NDT-based localization with the CARLA simulator.

## Build Commands

Each exercise is built independently in its own directory — there is no top-level build.

**Lessons 2 & 3** — direct compilation, no CMake:
```bash
g++ main.cpp && ./a.out
```

**Lessons 5 & 6** — CMake in-source build:
```bash
cmake . && make
```

**Lesson 7 (capstone)**:
```bash
# One-time: rebuild CARLA static libs
chmod +x make-libcarla-install.sh && ./make-libcarla-install.sh

cmake . && make
```

### Executable names per exercise

| Exercise | Executable |
|---|---|
| Lesson 5 – Intro to ICP | `./icp` |
| Lesson 5 – Creating ICP | `./icp` |
| Lesson 5 – Creating NDT | `./ndt` |
| Lesson 6 – ICP Alignment | `./scan_matching_1` |
| Lesson 6 – NDT Alignment | `./scan_matching_2` |
| Lesson 6 – Mapping | `./cloud_mapper` |
| Lesson 7 – Project | `./cloud_loc` |

### Exercises requiring CARLA simulator

Lessons 6 (Mapping) and 7 require CARLA running in a separate terminal before starting the exercise executable:
```bash
# Terminal 1
./run_carla.sh

# Terminal 2
./cloud_mapper   # or ./cloud_loc
```
Occasional core dump on startup is normal — just rerun.

## Architecture

### Lesson progression

| Lesson | Topic | Build style |
|---|---|---|
| 2 | C++ fundamentals | `g++` |
| 3 | 1D Markov/Bayes filter | `g++` |
| 5 | ICP & NDT from scratch | CMake + PCL |
| 6 | ICP/NDT alignment + CARLA mapping | CMake + PCL + CARLA |
| 7 | Full localization project (capstone) | CMake + PCL + CARLA |

Lesson 4 uses an external repo ([SFND_Lidar_Obstacle_Detection](https://github.com/udacity/SFND_Lidar_Obstacle_Detection)) and is not present here.

### Exercise file pattern

Every exercise in Lessons 5–7 follows the same layout:
```
Exercise-Name/
├── CMakeLists.txt
├── README.md
├── helper.h / helper.cpp    # shared utilities (see below)
├── <name>-main.cpp          # starter file with // TODO markers
└── solution/
    └── <name>-main-solution.cpp
```

Lesson 2 uses `challenges/challengeN/` for starters and `solutions/solutionN/` for answers. Lesson 3 exercises each have a `solution/` subdirectory alongside the starter `main.cpp`.

### Shared `helper.h` / `helper.cpp` (Lessons 5–7)

Defines all shared types and rendering utilities used across exercises:

- **Geometric types**: `Point`, `Rotate`, `Pose` (position + rotation), `Vect2`, `Color`, `BoxQ`, `LineSegment`, `Lidar`, `ControlState`
- **Transform helpers**: `transform2D()`, `transform3D()`, `getPose()` — convert between `Eigen::Matrix4d` and `Pose`
- **Visualization**: `renderPointCloud()`, `renderBox()`, `renderPath()`, `renderRay()` — wrap PCL visualizer calls
- **Utilities**: `print4x4Matrix()`, `getDistance()`, `minDistance()`, `getQuaternion()`

`PointCloudT` is typedef'd to `pcl::PointCloud<pcl::PointXYZ>`.

## Key Conventions

- **Student work lives in `<name>-main.cpp`**; `helper.h/cpp` is infrastructure — don't modify it unless fixing a bug there.
- **`// TODO` markers** indicate exactly where student code goes.
- **C++ standard**: C++14 for the Lesson 5 intro exercise; C++17 for all others (set in `CMakeLists.txt` per exercise).
- **Optimization flag**: `-O3` is set in all CMake builds; `-g` is commented out by default.
- **PCL version**: requires PCL ≥ 1.2 (`find_package(PCL 1.2 REQUIRED)`).
- **Git LFS**: `Lesson_6_Utilizing_Scan_Matching/Exercise-Mapping/libcarla-install/lib/libcarla_client.a` is >100 MB. Track with `git lfs track "*.a"` before committing changes that touch it.
- **In-source builds**: CMake is run inside the exercise directory (`cmake .`), so generated files (`CMakeCache.txt`, `CMakeFiles/`, `Makefile`) land alongside source files. These are gitignored.

## Dependencies

PCL, Eigen, Boost (filesystem), OpenCV, CMake ≥ 3.10, CARLA 0.9.9.4 (Lessons 6–7), Python 3, ROS.
