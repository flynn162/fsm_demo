// Copyright 2020 Flynn Liu
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <limits>
#include <new>

template<class Symbol, class State>
struct Node;

template<class Symbol, class State>
struct Edge {
    Symbol input;
    Node<Symbol, State>* next;
};

template<class Symbol, class State>
struct Node {
    State name;
    size_t n_edges;
    Edge<Symbol, State>* out_edges;
};

template<class Symbol, class State>
struct FsmInfo {
    size_t length;
    Node<Symbol, State>** nodes;
    Node<Symbol, State>* initial;
};

class FsmConcept {
public:
    virtual ~FsmConcept() = default;
protected:
    FsmConcept() = default;
    virtual size_t find_new_state(size_t symb, size_t n_edge);
    // to be implemented in the model
    virtual size_t get_symbol_as_int(size_t edge_idx) = 0;
};

template<class Symbol, class State>
class FsmModel : public FsmConcept {
public:
    FsmModel(FsmInfo<Symbol, State>* info) {
        this->info = info;
        this->current_node = this->info->initial;
        if (info->length > 0) {
            size_t size = this->info->length * sizeof(FsmHandler*);
            this->handlers = static_cast<FsmHandler**>(malloc(size));
            if (this->handlers == nullptr) {
                std::bad_alloc exception;
                throw exception;
            }
            memset(this->handlers, 0, size);
        } else {
            this->handlers = nullptr;
        }
    }

    virtual ~FsmModel() {
        if (this->handlers != nullptr) free(this->handlers);
    }

    Edge<Symbol, State>* get_edge(size_t idx) {
        return &(this->current_node->out_edges[idx]);
    }

    State get_state() {
        return this->current_node->name;
    }

    bool try_input(Symbol symbol) {
        const size_t INVALID = std::numeric_limits<std::size_t>::max();
        size_t n_edges = this->current_node->n_edges;
        size_t edge_idx = this->find_new_state(symbol, n_edges);
        if (edge_idx >= INVALID) {
            return false;
        } else {
            this->current_node = this->get_edge(edge_idx)->next;
            this->trigger_handler(symbol);
            return true;
        }
    }

protected:
    virtual size_t get_symbol_as_int(size_t edge_idx) {
        return this->get_edge(edge_idx)->input;
    }
private:
    void trigger_handler(Symbol symbol) {
        auto func = handlers[this->get_state()];
        if (func != nullptr) {
            func(symbol);
        }
    }

    static void handler_example(Symbol cause);
    typedef decltype(handler_example) FsmHandler;

    FsmInfo<Symbol, State>* info;
    FsmHandler** handlers;
    Node<Symbol, State>* current_node;
};
