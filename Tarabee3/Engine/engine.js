// مولَّد من server/engine بـ tools/build-engine.mjs — لا يُعدَّل باليد.
"use strict";
var Tarabee3Engine = (() => {
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

  // server/engine/index.ts
  var index_exports = {};
  __export(index_exports, {
    BOT_ACCURACY: () => BOT_ACCURACY,
    BOT_NAMES: () => BOT_NAMES,
    TIMES: () => TIMES,
    answer: () => answer,
    bridge: () => bridge,
    choose: () => choose,
    createMatch: () => createMatch,
    createTraining: () => createTraining,
    crossCells: () => crossCells,
    cyclesFor: () => cyclesFor,
    orderOf: () => orderOf,
    questionsNeeded: () => questionsNeeded,
    ranking: () => ranking,
    suggestedBoard: () => suggestedBoard,
    tick: () => tick,
    view: () => view
  });

  // server/engine/board.ts
  function crossCells(boardSize, row, col) {
    const cells = [
      { row, col },
      { row: row - 1, col },
      { row: row + 1, col },
      { row, col: col - 1 },
      { row, col: col + 1 }
    ];
    return cells.filter((c) => c.row >= 0 && c.row < boardSize && c.col >= 0 && c.col < boardSize);
  }
  var index = (boardSize, row, col) => row * boardSize + col;
  function inBoard(boardSize, row, col) {
    return Number.isInteger(row) && Number.isInteger(col) && row >= 0 && col >= 0 && row < boardSize && col < boardSize;
  }
  function canCenter(board, boardSize, row, col) {
    return inBoard(boardSize, row, col) && board[index(boardSize, row, col)] === 0;
  }
  function gain(board, boardSize, seatNo, row, col) {
    return crossCells(boardSize, row, col).filter((c) => board[index(boardSize, c.row, c.col)] !== seatNo).length;
  }
  function applyCross(board, boardSize, seatNo, row, col) {
    let changed = 0;
    for (const c of crossCells(boardSize, row, col)) {
      const i = index(boardSize, c.row, c.col);
      if (board[i] !== seatNo) changed++;
      board[i] = seatNo;
    }
    return changed;
  }
  var isFull = (board) => board.every((s) => s !== 0);
  function squaresOf(board, seatNo) {
    return board.reduce((n, s) => n + (s === seatNo ? 1 : 0), 0);
  }
  function ranking(board, seatNos) {
    const rows = seatNos.map((seatNo) => ({ seatNo, squares: squaresOf(board, seatNo) }));
    return rows.map((r) => ({ ...r, rank: 1 + rows.filter((o) => o.squares > r.squares).length })).sort((a, b) => a.rank - b.rank || a.seatNo - b.seatNo);
  }

  // server/engine/rng.ts
  function next(seed) {
    let t = seed + 1831565813 | 0;
    const s = t;
    t = Math.imul(t ^ t >>> 15, t | 1);
    t ^= t + Math.imul(t ^ t >>> 7, t | 61);
    return { value: ((t ^ t >>> 14) >>> 0) / 4294967296, seed: s };
  }
  function random(state) {
    const r = next(state.rng);
    state.rng = r.seed;
    return r.value;
  }
  function int(state, min, max) {
    return min + Math.floor(random(state) * (max - min + 1));
  }
  function shuffle(state, items) {
    const out2 = [...items];
    for (let i = out2.length - 1; i > 0; i--) {
      const j = int(state, 0, i);
      [out2[i], out2[j]] = [out2[j], out2[i]];
    }
    return out2;
  }

  // server/engine/bot.ts
  var BOT_ACCURACY = 0.6;
  var BOT_ANSWER_DELAY = [2500, 9e3];
  var BOT_CHOOSE_DELAY = [1500, 4e3];
  var BOT_NAMES = [
    "سهم",
    "نجم",
    "صقر",
    "ريم",
    "غيث",
    "مزن",
    "بدر",
    "سارية",
    "شهاب",
    "ندى",
    "فارس",
    "لمى"
  ];
  var EXPRESSIONS = ["مبتسم", "غامز", "غاضب", "مندهش", "نعسان", "مُخرج لسانه", "عيون نجوم", "واثق", "ضاحك", "متحمّس", "خجول", "مفكّر"];
  var HEADS = ["بلا", "شماغ", "طاقية", "كاب"];
  var EYES = ["بلا", "نظارة", "عين القرصان"];
  var NECKS = ["بلا", "شال"];
  var pick = (state, list) => list[int(state, 0, list.length - 1)];
  function botPersona(state) {
    return { expression: pick(state, EXPRESSIONS), head: pick(state, HEADS), eye: pick(state, EYES), neck: pick(state, NECKS) };
  }
  function planAnswer(state, at) {
    const correct = random(state) < BOT_ACCURACY;
    return { correct, botAt: at + int(state, BOT_ANSWER_DELAY[0], BOT_ANSWER_DELAY[1]) };
  }
  function botChoice(state, q, correct) {
    if (q.type === "truefalse") return correct ? q.correct : !q.correct;
    if (correct) return q.correct;
    const wrong = [1, 2, 3, 4].filter((n) => n !== q.correct);
    return pick(state, wrong);
  }
  function bestSquare(state, seatNo) {
    let best = -1;
    let options = [];
    for (let row = 0; row < state.boardSize; row++) {
      for (let col = 0; col < state.boardSize; col++) {
        if (!canCenter(state.board, state.boardSize, row, col)) continue;
        const g = gain(state.board, state.boardSize, seatNo, row, col);
        if (g > best) {
          best = g;
          options = [{ row, col }];
        } else if (g === best) options.push({ row, col });
      }
    }
    return options.length ? pick(state, options) : null;
  }
  function planChoose(state, at) {
    return at + int(state, BOT_CHOOSE_DELAY[0], BOT_CHOOSE_DELAY[1]);
  }

  // server/engine/types.ts
  var TIMES = { countdown: 3e3, answer: 15e3, choose: 2e4, display: 3e3 };

  // server/engine/engine.ts
  function cyclesFor(size, groupEnabled) {
    if (groupEnabled) return { 3: 9, 4: 8, 5: 10 }[size];
    return { 3: 12, 4: 12, 5: 10 }[size];
  }
  var suggestedBoard = (size) => ({ 3: 9, 4: 10, 5: 11 })[size];
  var clone = (s) => JSON.parse(JSON.stringify(s));
  function orderOf(state, cycle) {
    const n = state.firstOrder.length;
    const shift = (cycle - 1) % n;
    return [...state.firstOrder.slice(shift), ...state.firstOrder.slice(0, shift)];
  }
  function currentRound(state) {
    return state.rounds[state.rounds.length - 1];
  }
  function questionOf(state, id) {
    const q = state.pool.find((x) => x.id === id);
    if (!q) throw new Error(`question not in pool: ${id}`);
    return q;
  }
  var validTime = (t) => typeof t === "number" && Number.isFinite(t);
  function checkConfig(config, now) {
    if (![3, 4, 5].includes(config.size)) throw new Error("size must be 3, 4 or 5");
    if (![9, 10, 11].includes(config.boardSize)) throw new Error("boardSize must be 9, 10 or 11");
    const seatNos = config.seats.map((s) => s.seatNo).sort((a, b) => a - b);
    const expected = Array.from({ length: config.size }, (_, i) => i + 1);
    if (seatNos.join() !== expected.join()) throw new Error("seats must be numbered 1..size, once each");
    if (!validTime(now) || !Number.isFinite(config.seed)) throw new Error("now and seed must be finite numbers");
  }
  function createMatch(config, now) {
    checkConfig(config, now);
    const seatNos = config.seats.map((s) => s.seatNo);
    const times = config.times ?? TIMES;
    const state = {
      v: 1,
      size: config.size,
      boardSize: config.boardSize,
      groupEnabled: config.groupEnabled,
      cyclesTotal: cyclesFor(config.size, config.groupEnabled),
      times,
      seats: config.seats.map((s) => ({ ...s, persona: { ...s.persona } })),
      board: new Array(config.boardSize * config.boardSize).fill(0),
      firstOrder: [],
      cycle: 1,
      turnIndex: 0,
      rounds: [],
      pool: clone(config.questions),
      used: [],
      rng: config.seed | 0,
      phase: { kind: "countdown", until: now + times.countdown },
      startedAt: now,
      lastAt: now
    };
    state.firstOrder = shuffle(state, seatNos);
    return { state, events: [] };
  }
  function seatOf(state, seatNo) {
    return state.seats.find((s) => s.seatNo === seatNo);
  }
  function drawQuestion(state) {
    const unused = state.pool.filter((q2) => !state.used.includes(q2.id));
    if (unused.length === 0) throw new Error("question pool exhausted");
    const q = unused[int(state, 0, unused.length - 1)];
    state.used.push(q.id);
    return q;
  }
  function beginTurn(state, at, events) {
    const seatNo = orderOf(state, state.cycle)[state.turnIndex];
    const q = drawQuestion(state);
    const round = {
      id: state.rounds.length + 1,
      cycle: state.cycle,
      type: "turn",
      seatNo,
      questionId: q.id,
      startedAt: at,
      deadline: at + state.times.answer
    };
    state.rounds.push(round);
    if (seatOf(state, seatNo).isBot) {
      const plan = planAnswer(state, at);
      state.phase = { kind: "answering", deadline: round.deadline, botAt: Math.min(plan.botAt, round.deadline - 1), botCorrect: plan.correct };
    } else {
      state.phase = { kind: "answering", deadline: round.deadline };
    }
    events.push({ type: "turnStarted", at, roundId: round.id, seatNo });
  }
  function startDisplay(state, at) {
    const round = currentRound(state);
    round.displayUntil = at + state.times.display;
    state.phase = { kind: "display", until: round.displayUntil };
  }
  function isCorrect(q, choice) {
    return q.type === "mcq" ? choice === q.correct : choice === q.correct;
  }
  function validChoice(q, choice) {
    return q.type === "mcq" ? Number.isInteger(choice) && choice >= 1 && choice <= 4 : typeof choice === "boolean";
  }
  function doAnswer(state, choice, at, events) {
    const round = currentRound(state);
    const correct = isCorrect(questionOf(state, round.questionId), choice);
    round.answer = choice;
    round.answeredAt = at;
    round.result = correct ? "correct" : "wrong";
    events.push({ type: "answered", at, roundId: round.id, seatNo: round.seatNo, correct });
    if (!correct) {
      startDisplay(state, at);
      return;
    }
    const deadline = at + state.times.choose;
    state.phase = seatOf(state, round.seatNo).isBot ? { kind: "choosing", deadline, botAt: Math.min(planChoose(state, at), deadline - 1) } : { kind: "choosing", deadline };
  }
  function doChoose(state, row, col, at, events) {
    const round = currentRound(state);
    const changed = applyCross(state.board, state.boardSize, round.seatNo, row, col);
    round.choice = { row, col };
    events.push({ type: "chose", at, roundId: round.id, seatNo: round.seatNo, row, col, changed });
    startDisplay(state, at);
  }
  function afterDisplay(state, at, events) {
    if (isFull(state.board)) return end(state, at, "boardFull", events);
    state.turnIndex++;
    if (state.turnIndex >= state.size) {
      state.turnIndex = 0;
      state.cycle++;
    }
    if (state.cycle > state.cyclesTotal) return end(state, at, "turnsDone", events);
    beginTurn(state, at, events);
  }
  function end(state, at, reason, events) {
    state.phase = { kind: "ended", reason };
    state.endedAt = at;
    events.push({ type: "matchEnded", at, reason });
  }
  function tick(input, now) {
    const state = clone(input);
    const events = [];
    if (!validTime(now) || now < state.lastAt) return { state, events };
    state.lastAt = now;
    for (let guard = 0; guard < 1e4; guard++) {
      const p = state.phase;
      if (p.kind === "ended") break;
      if (p.kind === "countdown") {
        if (now < p.until) break;
        beginTurn(state, p.until, events);
      } else if (p.kind === "answering") {
        if (p.botAt !== void 0 && now >= p.botAt) {
          const round = currentRound(state);
          doAnswer(state, botChoice(state, questionOf(state, round.questionId), p.botCorrect), p.botAt, events);
        } else if (now >= p.deadline) {
          const round = currentRound(state);
          round.result = "timeout";
          events.push({ type: "timedOut", at: p.deadline, roundId: round.id, seatNo: round.seatNo });
          startDisplay(state, p.deadline);
        } else break;
      } else if (p.kind === "choosing") {
        if (p.botAt !== void 0 && now >= p.botAt) {
          const round = currentRound(state);
          const square = bestSquare(state, round.seatNo);
          if (square) doChoose(state, square.row, square.col, p.botAt, events);
          else {
            round.choiceDropped = true;
            startDisplay(state, p.botAt);
          }
        } else if (now >= p.deadline) {
          const round = currentRound(state);
          round.choiceDropped = true;
          events.push({ type: "choiceDropped", at: p.deadline, roundId: round.id, seatNo: round.seatNo });
          startDisplay(state, p.deadline);
        } else break;
      } else if (p.kind === "display") {
        if (now < p.until) break;
        afterDisplay(state, p.until, events);
      }
    }
    return { state, events };
  }
  function answer(input, seatNo, choice, at) {
    if (!validTime(at) || at < input.lastAt) return { state: clone(input), events: [], rejected: "bad_time" };
    const { state, events } = tick(input, at);
    const round = currentRound(state);
    if (state.phase.kind !== "answering" || !round) {
      const mine = round?.seatNo === seatNo;
      const rejected = mine && round?.answeredAt !== void 0 ? "already_answered" : mine && round?.result === "timeout" ? "too_late" : "not_now";
      return { state, events, rejected };
    }
    if (round.seatNo !== seatNo) return { state, events, rejected: "not_your_turn" };
    if (seatOf(state, seatNo).isBot) return { state, events, rejected: "not_your_turn" };
    const q = questionOf(state, round.questionId);
    if (!validChoice(q, choice)) return { state, events, rejected: "bad_choice" };
    doAnswer(state, choice, at, events);
    return { state, events };
  }
  function choose(input, seatNo, row, col, at) {
    if (!validTime(at) || at < input.lastAt) return { state: clone(input), events: [], rejected: "bad_time" };
    const { state, events } = tick(input, at);
    const round = currentRound(state);
    if (state.phase.kind !== "choosing" || !round) return { state, events, rejected: "not_now" };
    if (round.seatNo !== seatNo || seatOf(state, seatNo).isBot) return { state, events, rejected: "not_your_turn" };
    if (!canCenter(state.board, state.boardSize, row, col)) return { state, events, rejected: "bad_square" };
    doChoose(state, row, col, at, events);
    return { state, events };
  }

  // server/engine/training.ts
  function questionsNeeded(size) {
    const turns = size * Math.max(cyclesFor(size, true), cyclesFor(size, false));
    return turns + 5;
  }
  function createTraining(setup, now) {
    if (setup.questions.length < questionsNeeded(setup.size)) throw new Error("training pack too small");
    const picker = { rng: setup.seed ^ 1540483477 };
    const names = shuffle(picker, BOT_NAMES).slice(0, setup.size - 1);
    const seats = [
      { seatNo: 1, isBot: false, displayName: setup.player.displayName, persona: setup.player.persona },
      ...names.map((name, i) => ({ seatNo: i + 2, isBot: true, displayName: name, persona: botPersona(picker) }))
    ];
    return createMatch({
      size: setup.size,
      boardSize: setup.boardSize,
      // الجولات الجماعية تأتي في M-05؛ حتى ذلك تُحسب الدورات بها كما في المباراة الأون لاين
      groupEnabled: true,
      seats,
      questions: setup.questions,
      seed: setup.seed ^ int(picker, 1, 2147483647)
    }, now);
  }

  // server/engine/view.ts
  function view(state) {
    const p = state.phase;
    const phase = p.kind === "answering" ? { kind: "answering", deadline: p.deadline } : p.kind === "choosing" ? { kind: "choosing", deadline: p.deadline } : p;
    const r = currentRound(state);
    let round;
    if (r) {
      const q = questionOf(state, r.questionId);
      const over = r.result !== void 0;
      round = {
        id: r.id,
        seatNo: r.seatNo,
        deadline: r.deadline,
        question: {
          id: q.id,
          type: q.type,
          text: q.text,
          ...q.type === "mcq" ? { options: [...q.options] } : {},
          ...over ? { correct: q.correct } : {}
        },
        ...r.answer !== void 0 ? { answer: r.answer } : {},
        ...r.result ? { result: r.result } : {},
        ...r.choice ? { choice: r.choice } : {},
        ...r.choiceDropped ? { choiceDropped: true } : {}
      };
    }
    return {
      size: state.size,
      boardSize: state.boardSize,
      cycle: state.cycle,
      cyclesTotal: state.cyclesTotal,
      times: { ...state.times },
      board: [...state.board],
      seats: state.seats.map((s) => ({ ...s, persona: { ...s.persona }, squares: squaresOf(state.board, s.seatNo) })),
      order: orderOf(state, Math.min(state.cycle, state.cyclesTotal)),
      phase,
      ...round ? { round } : {},
      ...p.kind === "ended" ? { ranking: ranking(state.board, state.seats.map((s) => s.seatNo)) } : {}
    };
  }

  // server/engine/index.ts
  var out = (r) => JSON.stringify({ state: JSON.stringify(r.state), view: view(r.state), events: r.events, ...r.rejected ? { rejected: r.rejected } : {} });
  var bridge = {
    createTraining: (setupJson, now) => out(createTraining(JSON.parse(setupJson), now)),
    tick: (stateJson, now) => out(tick(JSON.parse(stateJson), now)),
    answer: (stateJson, seatNo, choiceJson, now) => out(answer(JSON.parse(stateJson), seatNo, JSON.parse(choiceJson), now)),
    choose: (stateJson, seatNo, row, col, now) => out(choose(JSON.parse(stateJson), seatNo, row, col, now)),
    // قواعد يحتاجها العرض قبل الحكم، من المحرّك نفسه لا مكرّرة في سويفت (مراجعة M-04، المشكلة ٤)
    crossCells: (boardSize, row, col) => JSON.stringify(crossCells(boardSize, row, col)),
    suggestedBoard: (size) => suggestedBoard(size)
  };
  return __toCommonJS(index_exports);
})();
