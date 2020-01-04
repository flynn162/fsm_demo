# Finite State Machine Demonstration

You have encoutered a koopa, who is a finite state machine. From the symbol enum, you have a list of options. Your goal is to kill it.

## Compiling

You will need:

- GNU Make
- g++ (or some general C++ 14 compiler)
- optionally, some R7RS Scheme implementation; see below

To build, just run `make`.
If you need a "release-grade" binary, run `make clean && make MODE=release`.

## Changing the FSM graph

Two files are automatically generated, and they are included in the repo:

- koopa_graph.inc.hpp
- koopa_graph.inc.cpp

If you delete any of these files,  you will need one of the following R7RS Scheme implementations to remake it:

- Gauche (used by default, just run `make`)
- Chibi Scheme (run `make R7RS=chibi-scheme`)
- Racket (requires the [r7rs](https://pkgs.racket-lang.org/package/r7rs) and [srfi-lib](https://pkgs.racket-lang.org/package/srfi-lib) packages, run `make R7RS='racket -n -l r7rs --script'`)

To change the finite state machine, you will need to modify `koopa_graph.scm`, and recompile the program with `make clean-inc && make [R7RS=...]`.

## Makefile options

Cleaning:

- `make clean` (delete the binaries, objects and temporary files, but keep the generated source code)
-  `make clean-inc` (delete the generated source code)
- `make clean!` (delete every single generated file)

Changing parameters:

- `make R7RS='gosh -r7 -bq'` (change the R7RS Scheme implementation)
- `make CXX=clang++` (change the C++ compiler)
- `make CXXFLAGS='-std=c++14 -O2 -Wall'` (change the C++ compiler flags)
- `CXXLFAGS='-Wextra -Werror' make` (add more C++ compiler flags to the default ones)

## Sample output

```
$ ./program
You have encountered a koopa. The enemy's state is WALKING_LEFT.

Choose an action [#] ?
Invalid input!
0 STOMP
1 FIREBALL
2 HIT_WALL_LEFT
3 HIT_WALL_RIGHT
4 KICKED_FROM_LEFT
5 KICKED_FROM_RIGHT
6 TIMER_EXPIRED
The enemy's state is WALKING_LEFT.

Choose an action [#] 0
The action is STOMP. It is super effective.
The enemy's state is HIDING_IN_SHELL.

Choose an action [#] 4
The action is KICKED_FROM_LEFT. It is super effective.
The enemy's state is ROLLING_RIGHT.

Choose an action [#] 3
The action is HIT_WALL_RIGHT. It is super effective.
The enemy's state is ROLLING_LEFT.

Choose an action [#] 6
The action is TIMER_EXPIRED. It is unavailable right now.
The enemy's state is ROLLING_LEFT.

Choose an action [#] 1
The action is FIREBALL. It is super effective.
Oh, our turtle is dead.
```

## License

Copyright 2020 Flynn Liu

SPDX-License-Identifier: Apache-2.0
