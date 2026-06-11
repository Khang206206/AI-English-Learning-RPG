# Sequence Diagram - AI English Learning RPG

Tai lieu nay mo ta cac luong tuong tac chinh cua he thong game Godot: khoi dong game, quiz dau game, chien dau hoc tu vung/ngu phap, shop va notebook.

## 1. Khoi Dong Game Va Nap Du Lieu

```mermaid
sequenceDiagram
    autonumber
    participant Godot as Godot Engine
    participant DB as DatabaseManager
    participant SQLite as SQLite data.db
    participant CSV as CSV Files
    participant Progress as ProgressManager
    participant AI as AIManager

    Godot->>DB: _ready()
    DB->>DB: init_database()
    DB->>SQLite: open_db(DB_PATH)
    SQLite-->>DB: connection OK
    DB->>SQLite: CREATE TABLE IF NOT EXISTS ...
    DB->>SQLite: run migrations
    DB->>CSV: read enemies.csv, vocabulary.csv, grammar.csv
    CSV-->>DB: seed data
    DB->>SQLite: INSERT/UPDATE seed rows
    DB->>SQLite: SELECT Player_Profile by save slot
    SQLite-->>DB: save data
    DB->>DB: load_game()
    DB-->>Godot: emit hp_changed, gold_changed, game_loaded

    Godot->>Progress: autoload ready
    Progress-->>Godot: expose learning/progress APIs

    Godot->>AI: _ready()
    AI->>AI: init question queues for tiers
    AI->>AI: check_and_fill_all_queues()
    AI->>Progress: get_weakest_vocab() or get_weakest_grammar()
    Progress->>SQLite: query weakest mastery item
    SQLite-->>Progress: vocab/grammar row
    Progress-->>AI: target learning item
    AI->>AI: generate queued question or fallback
```

## 2. Quiz Dau Game Va Danh Gia CEFR

```mermaid
sequenceDiagram
    autonumber
    actor Player
    participant Obj as InteractableObject
    participant Quiz as QuizUI
    participant Ollama as Ollama API
    participant AI as AIManager
    participant DB as DatabaseManager

    Player->>Obj: press interact near QuizBook/NPC
    Obj->>Quiz: start_quiz()
    Quiz->>Quiz: show quiz and pause game

    loop 15 intro questions
        Quiz-->>Player: show question and answers
        Player->>Quiz: select answer
        Quiz->>Quiz: store result and mark correct/wrong
    end

    Quiz->>Quiz: finish_quiz()
    Quiz->>AI: read OLLAMA_MODEL / OLLAMA_URL
    Quiz->>Ollama: POST /api/chat with score and mistakes

    alt Ollama returns valid JSON
        Ollama-->>Quiz: { level, elaria_comment }
        Quiz-->>Player: show CEFR level and comment
    else Ollama fails or JSON invalid
        Quiz->>Quiz: _show_local_assessment()
        Quiz-->>Player: show fallback level by score
    end

    Quiz->>DB: mark_intro_quiz_completed()
    DB->>DB: update save profile
    DB-->>Obj: emit intro_quiz_state_changed(true)
    Quiz-->>Obj: emit quiz_completed
    Player->>Quiz: press Enter/click
    Quiz->>Quiz: hide quiz and unpause game
```

## 3. Luong Chien Dau Hoc Tap

```mermaid
sequenceDiagram
    autonumber
    actor Player
    participant Obj as InteractableObject
    participant GM as GameManager
    participant Progress as ProgressManager
    participant DB as DatabaseManager
    participant AI as AIManager
    participant Battle as BattleScene
    participant SQLite as SQLite data.db
    participant Ollama as Ollama API

    Player->>Obj: press interact near enemy
    Obj->>Progress: can_access_tier(monster.tier_id)
    Progress->>SQLite: query previous tier mastery
    SQLite-->>Progress: mastery value

    alt tier locked
        Obj-->>Player: show Elaria locked dialogue
    else tier available
        Obj->>GM: set current_monster, current_enemy_id
        Obj->>DB: mark_enemy_interacted(enemy_id)
        Obj->>AI: set_tier(monster.tier_id)
        Obj->>GM: save previous_scene_path and player_position
        Obj->>DB: restore_full_hp()
        Obj->>DB: save_game(position, scene)
        Obj->>Battle: change_scene_to_file(BattleScene)
    end

    Battle->>GM: read current_monster
    Battle->>DB: get_enemy_hp_for_tier()
    Battle->>AI: get_question()

    alt question queue has data
        AI-->>Battle: queued question
    else queue empty
        AI->>Progress: get_weakest_vocab(current_tier)
        Progress->>SQLite: query weakest vocab
        SQLite-->>Progress: vocab row
        Progress-->>AI: vocab item
        AI-->>Battle: emergency fallback question
    end

    par background question generation
        AI->>Progress: get_weakest_vocab() or get_weakest_grammar()
        Progress->>SQLite: query mastery data
        SQLite-->>Progress: target item
        Progress-->>AI: target item
        AI->>Ollama: POST /api/chat generate JSON question
        alt valid response
            Ollama-->>AI: JSON question
            AI->>AI: normalize and push to queue
        else timeout/error
            AI->>AI: push fallback question
        end
    and combat turn
        Battle-->>Player: show question, answers, timer, items, spells
        Player->>Battle: answer / submit text / timer timeout

        alt answer correct
            Battle->>Battle: play player attack and spell effect
            Battle->>Battle: reduce monster HP
            Battle->>Progress: update_after_answer() or update_grammar_after_answer()
            Progress->>SQLite: insert/update mastery and SRS
            Progress->>DB: emit hp_changed if needed

            alt monster defeated
                Battle->>DB: restore_full_hp()
                Battle->>DB: add_gold(reward)
                Battle->>DB: mark_enemy_dead(enemy_id)
                Battle->>DB: save_game(previous position, previous scene)
                Battle-->>Player: show VICTORY overlay
            else monster alive
                Battle->>AI: load_next_question()
            end
        else answer wrong or timeout
            Battle->>Battle: play monster attack
            Battle->>Progress: update_after_answer(false) or update_grammar_after_answer(false)
            Progress->>DB: reduce HP and emit hp_changed
            Progress->>SQLite: update mastery/SRS and Player_Profile.hp
            Battle-->>Player: show AI tutor explanation

            alt player HP <= 0
                Battle->>DB: restore_full_hp()
                Battle-->>Player: show GAME OVER overlay
            else player alive
                Player->>Battle: close tutor popup
                Battle->>AI: load_next_question()
            end
        end
    end
```

## 4. Dung Vat Pham Va Phep Trong Tran Dau

```mermaid
sequenceDiagram
    autonumber
    actor Player
    participant Battle as BattleScene
    participant Progress as ProgressManager
    participant DB as DatabaseManager
    participant SQLite as SQLite data.db

    Player->>Battle: click item/spell button

    alt use potion
        Battle->>Progress: consume_item(1)
        Progress->>SQLite: decrement Player_Inventory
        Battle->>DB: set_player_hp(player_hp + 4)
        DB->>SQLite: update Player_Profile.hp
        DB-->>Battle: emit hp_changed
    else use fifty-fifty
        Battle->>Progress: consume_item(2)
        Progress->>SQLite: decrement Player_Inventory
        Battle->>Battle: hide 2 wrong answers or reveal text prefix
    else use skip
        Battle->>Progress: consume_item(3)
        Progress->>SQLite: decrement Player_Inventory
        Battle->>Battle: stop timer and load_next_question()
    else use time freeze
        Battle->>Progress: consume_item(4)
        Progress->>SQLite: decrement Player_Inventory
        Battle->>Battle: stop timer for 10 seconds
    else select elemental spell
        Battle->>Progress: get_inventory()
        Progress->>SQLite: query available spell items
        Battle->>Battle: set current_bullet to fire/ice/electric/wood
    end
```

## 5. Shop Va Notebook

```mermaid
sequenceDiagram
    autonumber
    actor Player
    participant Shop as ShopUI
    participant Item as ShopItem
    participant Notebook as NotebookUI
    participant Progress as ProgressManager
    participant DB as DatabaseManager
    participant SQLite as SQLite data.db

    alt open shop
        Player->>Shop: open shop UI
        Shop->>DB: get_gold()
        Shop->>SQLite: query Item_Dict and Player_Inventory
        SQLite-->>Shop: item list with owned quantity
        Shop-->>Player: render spell/item tabs
        Player->>Item: click buy
        Item->>DB: spend_gold(price)
        DB->>SQLite: update Player_Profile.gold
        DB-->>Shop: emit gold_changed
        Item->>Progress: add_item(item_id, qty)
        Progress->>SQLite: insert/update Player_Inventory
        Shop->>Shop: refresh current tab
    else open notebook
        Player->>Notebook: toggle_notebook()
        Notebook->>Notebook: pause game and play open animation
        Notebook->>DB: search_encountered_vocab(filter)
        DB->>SQLite: query Vocabulary_Bank and Player_Vocab_Mastery
        SQLite-->>DB: vocab mastery rows
        DB-->>Notebook: vocab data
        Notebook-->>Player: render vocabulary and mastery detail
        Player->>Notebook: switch grammar tab
        Notebook-->>Player: render unlocked grammar spell info
    end
```

