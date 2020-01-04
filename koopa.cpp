// Copyright 2020 Flynn Liu
// SPDX-License-Identifier: Apache-2.0

#include "koopa.hpp"
#include <stddef.h>
#include <limits>

static const size_t SIZE_T_MAX = std::numeric_limits<std::size_t>::max();

size_t FsmConcept::find_new_state(size_t symb, size_t n_edge) {
    // perform a binary search over the edges
    if (n_edge == 0) {
        return SIZE_T_MAX;
    }
    size_t start = 0;
    size_t end = n_edge - 1;
    if (symb < this->get_symbol_as_int(start) ||
        symb > this->get_symbol_as_int(end)) {
        return SIZE_T_MAX;
    }

    while (start <= end) {
        if (this->get_symbol_as_int(start) == symb) {
            return start;
        } else if (start != end && this->get_symbol_as_int(end) == symb) {
            return end;
        } else {
            // it is not the start and not the end
            if (start == end) {
                // not found
                return SIZE_T_MAX;
            }
            // else: start < end
            size_t step = (end - start) / 2;
            if (step == 0) step = 1;
            size_t half = start + step;
            size_t value = this->get_symbol_as_int(half);
            if (symb < value) {
                end = half;
                start++;
            } else {
                start = half;
                end--;
            }
        }
    }
    // not found (also unreachable)
    return SIZE_T_MAX;
}
