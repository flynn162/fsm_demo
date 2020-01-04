// Copyright 2020 Flynn Liu
// SPDX-License-Identifier: Apache-2.0

#include "koopa.hpp"
#include "koopa_graph.hpp"
#include <iostream>
#include <stddef.h>
#include <limits>

// enum strings
static const char* state_names[] = {
  "WALKING_LEFT",
  "WALKING_RIGHT",
  "HIDING_IN_SHELL",
  "ROLLING_LEFT",
  "ROLLING_RIGHT",
  "DEAD"
};

static const char* symbol_names[] = {
  "STOMP",
  "FIREBALL",
  "HIT_WALL_LEFT",
  "HIT_WALL_RIGHT",
  "KICKED_FROM_LEFT",
  "KICKED_FROM_RIGHT",
  "TIMER_EXPIRED",
  nullptr
};

void print_actions() {
    size_t i = 0;
    while (symbol_names[i] != nullptr) {
        std::cout << i << " " << symbol_names[i] << "\n";
        i++;
    }
}

int main() {
    koopa::init();
    Koopa enemy = Koopa();
    std::cout << "You have encountered a koopa. ";

    auto state = enemy.get_state();
    while (state != koopa::DEAD) {
        std::cout << "The enemy's state is " << state_names[state];
        std::cout << ".\n\nChoose an action [#] ";
        // accept input
        int action;
        std::cin >> action;
        if (std::cin.fail()) {
            std::cin.clear();
            std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
            action = -1;
        }
        if (action < 0 || action >= koopa::NR_KoopaSymbol) {
            std::cout << "Invalid input!\n";
            print_actions();
            continue;
        }
        std::cout << "The action is " << symbol_names[action] << ". ";
        // try to move from one state to the next
        if (!enemy.try_input(static_cast<koopa::KoopaSymbol>(action))) {
            std::cout << "It is unavailable right now.\n";
        } else {
            std::cout << "It is super effective.\n";
        }

        state = enemy.get_state();
    }
    std::cout << "Oh, our turtle is dead.\n";
    return 0;
}
