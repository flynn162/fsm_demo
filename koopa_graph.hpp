// Copyright 2020 Flynn Liu
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include "koopa.hpp"

namespace koopa {
#include "koopa_graph.inc.hpp"
};

class Koopa : public FsmModel<koopa::KoopaSymbol, koopa::KoopaState> {
public:
    Koopa() : FsmModel(&koopa::koopa_graph) {}
    virtual ~Koopa() = default;
};
