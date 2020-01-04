;; Copyright 2020 Flynn Liu
;; SPDX-License-Identifier: Apache-2.0

(define-states KoopaState
  (walking-left
   walking-right
   hiding-in-shell
   rolling-left
   rolling-right
   dead))

(define-symbols KoopaSymbol
  (stomp
   fireball
   hit-wall-left
   hit-wall-right
   kicked-from-left
   kicked-from-right
   timer-expired))

(define-fsm (koopa-graph walking-left)
  (walking-left ((hit-wall-left walking-right)
                 (stomp hiding-in-shell)
                 (fireball dead)))

  (walking-right ((hit-wall-right walking-left)
                  (stomp hiding-in-shell)
                  (fireball dead)))

  (hiding-in-shell ((kicked-from-left rolling-right)
                    (kicked-from-right rolling-left)
                    (timer-expired walking-left)
                    (fireball dead)))

  (rolling-right ((hit-wall-right rolling-left)
                  (stomp hiding-in-shell)
                  (fireball dead)))

  (rolling-left ((hit-wall-left rolling-right)
                 (stomp hiding-in-shell)
                 (fireball dead)))

  (dead ()))
