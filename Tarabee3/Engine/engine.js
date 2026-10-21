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
    BOXES_PER_SEAT: () => BOXES_PER_SEAT,
    CARD_TYPES: () => CARD_TYPES,
    PAUSE_MS: () => PAUSE_MS,
    TIMES: () => TIMES,
    answer: () => answer,
    boxAllowed: () => boxAllowed,
    bridge: () => bridge,
    cardBlock: () => cardBlock,
    centerAllowed: () => centerAllowed,
    centersNeeded: () => centersNeeded,
    choose: () => choose,
    clearAllowed: () => clearAllowed,
    createMatch: () => createMatch,
    createTraining: () => createTraining,
    crossCells: () => crossCells,
    currentRound: () => currentRound,
    cyclesFor: () => cyclesFor,
    decideBurn: () => decideBurn,
    heldCards: () => heldCards,
    orderOf: () => orderOf,
    playCard: () => playCard,
    questionsNeeded: () => questionsNeeded,
    ranking: () => ranking,
    setPresence: () => setPresence,
    suggestedBoard: () => suggestedBoard,
    tick: () => tick,
    view: () => view,
    wakeAt: () => wakeAt,
    withdraw: () => withdraw
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
  function fortifiedSet(boardSize, forts) {
    const set = /* @__PURE__ */ new Set();
    for (const f of forts) {
      for (const c of crossCells(boardSize, f.center.row, f.center.col)) set.add(index(boardSize, c.row, c.col));
    }
    return set;
  }
  function canCenter(board, boardSize, row, col, fortified2, anywhere = false) {
    if (!inBoard(boardSize, row, col)) return false;
    const i = index(boardSize, row, col);
    if (fortified2.has(i)) return false;
    return anywhere || board[i] === 0;
  }
  function gain(board, boardSize, seatNo, row, col, fortified2) {
    return crossCells(boardSize, row, col).map((c) => index(boardSize, c.row, c.col)).filter((i) => !fortified2.has(i) && board[i] !== seatNo).length;
  }
  function applyCross(board, boardSize, seatNo, row, col, fortified2) {
    const changes = [];
    for (const c of crossCells(boardSize, row, col)) {
      const i = index(boardSize, c.row, c.col);
      if (fortified2.has(i) || board[i] === seatNo) continue;
      changes.push({ index: i, from: board[i] });
      board[i] = seatNo;
    }
    return changes;
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
  function planAnswer(state, at, deadline) {
    const correct = random(state) < BOT_ACCURACY;
    return { correct, botAt: Math.min(at + int(state, BOT_ANSWER_DELAY[0], BOT_ANSWER_DELAY[1]), deadline - 1) };
  }
  function botChoice(state, q, correct) {
    if (q.type === "truefalse") return correct ? q.correct : !q.correct;
    if (correct) return q.correct;
    const wrong = [1, 2, 3, 4].filter((n) => n !== q.correct);
    return pick(state, wrong);
  }
  function bestSquare(state, seatNo) {
    const fortified2 = fortifiedSet(state.boardSize, state.fortifications);
    let best = -1;
    let options = [];
    for (let row = 0; row < state.boardSize; row++) {
      for (let col = 0; col < state.boardSize; col++) {
        if (!canCenter(state.board, state.boardSize, row, col, fortified2)) continue;
        const g = gain(state.board, state.boardSize, seatNo, row, col, fortified2);
        if (g > best) {
          best = g;
          options = [{ row, col }];
        } else if (g === best) options.push({ row, col });
      }
    }
    return options.length ? pick(state, options) : null;
  }
  function planChoose(state, at, deadline) {
    return Math.min(at + int(state, BOT_CHOOSE_DELAY[0], BOT_CHOOSE_DELAY[1]), deadline - 1);
  }

  // server/engine/types.ts
  var TIMES = { countdown: 3e3, answer: 15e3, choose: 2e4, display: 3e3, burn: 1e4 };
  var CARD_TYPES = [
    "burn",
    "swap_question",
    "any_answer",
    "clear_squares",
    "fortify",
    "double_cross",
    "place_anywhere"
  ];
  var BOXES_PER_SEAT = 2;

  // server/engine/engine.ts
  function cyclesFor(size, groupEnabled) {
    if (groupEnabled) return { 3: 9, 4: 8, 5: 10 }[size];
    return { 3: 12, 4: 12, 5: 10 }[size];
  }
  var suggestedBoard = (size) => ({ 3: 9, 4: 10, 5: 11 })[size];
  var validTime = (t) => typeof t === "number" && Number.isFinite(t);
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
    const times = { ...TIMES, ...config.times };
    const state = {
      v: 2,
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
      groupsDone: [],
      rounds: [],
      // الآلي لا يفتح الصناديق (RULES-cards)
      boxes: Object.fromEntries(config.seats.map((s) => [String(s.seatNo), s.isBot ? 0 : BOXES_PER_SEAT])),
      cards: [],
      fortifications: [],
      fortsCreated: 0,
      pool: clone(config.questions),
      used: [],
      rng: config.seed | 0,
      phase: { kind: "countdown", until: now + times.countdown },
      startedAt: now,
      lastAt: now
    };
    state.firstOrder = shuffle(state, config.seats.map((s) => s.seatNo));
    return { state, events: [] };
  }
  var seatOf = (state, seatNo) => state.seats.find((s) => s.seatNo === seatNo);
  var isBot = (state, seatNo) => seatOf(state, seatNo)?.isBot === true;
  var isAway = (state, seatNo) => state.away?.includes(seatNo) === true;
  var robot = (state, seatNo) => isBot(state, seatNo) || isAway(state, seatNo);
  var fortified = (state) => fortifiedSet(state.boardSize, state.fortifications);
  var heldCards = (state, seatNo) => state.cards.filter((c) => c.seatNo === seatNo && c.status === "held");
  function drawQuestion(state) {
    const unused = state.pool.filter((q2) => !state.used.includes(q2.id));
    if (unused.length === 0) throw new Error("question pool exhausted");
    const q = unused[int(state, 0, unused.length - 1)];
    state.used.push(q.id);
    return q;
  }
  function ageFortifications(state, seatNo, at, events) {
    for (const f of state.fortifications) if (f.ownerSeat === seatNo) f.ownerTurnsSince++;
    for (const f of state.fortifications) if (f.ownerTurnsSince >= 3) events.push({ type: "fortificationEnded", at, id: f.id });
    state.fortifications = state.fortifications.filter((f) => f.ownerTurnsSince < 3);
  }
  function beginTurn(state, at, events) {
    const seatNo = orderOf(state, state.cycle)[state.turnIndex];
    ageFortifications(state, seatNo, at, events);
    const q = drawQuestion(state);
    const round = {
      id: state.rounds.length + 1,
      cycle: state.cycle,
      type: "turn",
      seatNo,
      chooser: seatNo,
      questionId: q.id,
      startedAt: at,
      deadline: at + state.times.answer
    };
    state.rounds.push(round);
    if (isBot(state, seatNo)) {
      const plan = planAnswer(state, at, round.deadline);
      state.phase = { kind: "answering", deadline: round.deadline, botAt: plan.botAt, botCorrect: plan.correct };
    } else {
      state.phase = { kind: "answering", deadline: round.deadline };
    }
    events.push({ type: "turnStarted", at, roundId: round.id, seatNo });
  }
  function beginGroup(state, at, events) {
    const q = drawQuestion(state);
    const round = {
      id: state.rounds.length + 1,
      cycle: state.cycle,
      type: "group",
      questionId: q.id,
      startedAt: at,
      deadline: at + state.times.answer,
      groupAnswers: []
    };
    state.rounds.push(round);
    state.groupsDone.push(state.cycle);
    const bots = state.seats.filter((s) => s.isBot).map((s) => {
      const plan = planAnswer(state, at, round.deadline);
      return { seatNo: s.seatNo, at: plan.botAt, correct: plan.correct };
    });
    state.phase = { kind: "group", deadline: round.deadline, bots };
    events.push({ type: "groupStarted", at, roundId: round.id });
  }
  function startDisplay(state, at) {
    const round = currentRound(state);
    round.displayUntil = at + state.times.display;
    state.phase = { kind: "display", until: round.displayUntil };
  }
  function grantChoice(state, chooser, at) {
    const round = currentRound(state);
    round.chooser = chooser;
    const deadline = at + state.times.choose;
    state.phase = robot(state, chooser) ? { kind: "choosing", deadline, botAt: planChoose(state, at, deadline) } : { kind: "choosing", deadline };
  }
  var isCorrect = (q, choice) => choice === q.correct;
  function validChoice(q, choice) {
    return q.type === "mcq" ? Number.isInteger(choice) && choice >= 1 && choice <= 4 : typeof choice === "boolean";
  }
  function doAnswer(state, choice, at, events) {
    const round = currentRound(state);
    const correct = round.anyAnswer === true || isCorrect(questionOf(state, round.questionId), choice);
    round.answer = choice;
    round.answeredAt = at;
    round.result = correct ? "correct" : "wrong";
    events.push({ type: "answered", at, roundId: round.id, seatNo: round.seatNo, correct });
    if (correct) grantChoice(state, round.seatNo, at);
    else startDisplay(state, at);
  }
  function groupAnswer(state, seatNo, choice, at, events) {
    const round = currentRound(state);
    round.groupAnswers.push({ seatNo, choice, at, correct: isCorrect(questionOf(state, round.questionId), choice) });
    events.push({ type: "groupAnswered", at, roundId: round.id, seatNo });
    if (round.groupAnswers.length === state.size) endGroup(state, at, events);
  }
  function endGroup(state, at, events) {
    const round = currentRound(state);
    const winner = round.groupAnswers.filter((a) => a.correct).sort((a, b) => a.at - b.at)[0];
    round.result = winner ? "correct" : "noWinner";
    round.answeredAt = at;
    if (winner) round.winnerSeat = winner.seatNo;
    events.push({ type: "groupEnded", at, roundId: round.id, winnerSeat: winner?.seatNo ?? null });
    if (winner) grantChoice(state, winner.seatNo, at);
    else startDisplay(state, at);
  }
  function openBurnWindows(state, attacker, changes, at, then, events) {
    const lost = /* @__PURE__ */ new Map();
    for (const c of changes) {
      if (c.from === 0 || c.from === attacker || isAway(state, c.from)) continue;
      if (!heldCards(state, c.from).some((card) => card.type === "burn")) continue;
      const cells = lost.get(c.from) ?? [];
      cells.push({ row: Math.floor(c.index / state.boardSize), col: c.index % state.boardSize });
      lost.set(c.from, cells);
    }
    if (lost.size === 0) return false;
    const windows = [...lost.entries()].map(([seatNo, cells]) => ({ seatNo, cells }));
    state.phase = { kind: "burn", until: at + state.times.burn, windows, then };
    events.push({ type: "burnWindows", at, seats: windows.map((w) => w.seatNo) });
    return true;
  }
  function finishBurn(state, at) {
    if (state.phase.kind !== "burn") return;
    const then = state.phase.then;
    if (then.kind === "answering") {
      const round = currentRound(state);
      round.deadline = at + then.remaining;
      state.phase = { kind: "answering", deadline: round.deadline };
    } else {
      startDisplay(state, at);
    }
  }
  function doSquare(state, centers, at, events) {
    const round = currentRound(state);
    const chooser = round.chooser;
    const forts = fortified(state);
    const before = [...state.board];
    for (const c of centers) applyCross(state.board, state.boardSize, chooser, c.row, c.col, forts);
    const changes = [];
    state.board.forEach((owner, i) => {
      if (owner !== before[i]) changes.push({ index: i, from: before[i] });
    });
    round.choice = "square";
    round.centers = centers;
    events.push({ type: "chose", at, roundId: round.id, seatNo: chooser, centers, changed: changes.length });
    if (!openBurnWindows(state, chooser, changes, at, { kind: "display" }, events)) startDisplay(state, at);
  }
  function doBox(state, at, events) {
    const round = currentRound(state);
    const seatNo = round.chooser;
    state.boxes[String(seatNo)] = (state.boxes[String(seatNo)] ?? 0) - 1;
    const type = CARD_TYPES[int(state, 0, CARD_TYPES.length - 1)];
    const card = {
      id: state.cards.length + 1,
      seatNo,
      type,
      status: "held",
      gainedRound: round.id,
      ...type === "clear_squares" ? { clearCount: int(state, 1, 2) } : {}
    };
    state.cards.push(card);
    round.choice = "box";
    round.boxCard = card.id;
    events.push({ type: "boxOpened", at, roundId: round.id, seatNo, card: type, ...card.clearCount ? { clearCount: card.clearCount } : {} });
    startDisplay(state, at);
  }
  function afterDisplay(state, at, events) {
    if (isFull(state.board)) return end(state, at, "boardFull", events);
    if (currentRound(state).type === "turn") {
      state.turnIndex++;
      if (state.turnIndex < state.size) return beginTurn(state, at, events);
      if (state.groupEnabled && state.cycle % 2 === 0 && !state.groupsDone.includes(state.cycle)) {
        return beginGroup(state, at, events);
      }
    }
    state.cycle++;
    state.turnIndex = 0;
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
        const round = currentRound(state);
        if (p.botAt !== void 0 && now >= p.botAt) {
          doAnswer(state, botChoice(state, questionOf(state, round.questionId), p.botCorrect), p.botAt, events);
        } else if (now >= p.deadline) {
          if (round.anyAnswer) {
            const q = questionOf(state, round.questionId);
            doAnswer(state, q.type === "mcq" ? int(state, 1, 4) : int(state, 0, 1) === 1, p.deadline, events);
          } else if (isAway(state, round.seatNo)) {
            const q = questionOf(state, round.questionId);
            doAnswer(state, botChoice(state, q, random(state) < BOT_ACCURACY), p.deadline, events);
          } else {
            round.result = "timeout";
            events.push({ type: "timedOut", at: p.deadline, roundId: round.id, seatNo: round.seatNo });
            startDisplay(state, p.deadline);
          }
        } else break;
      } else if (p.kind === "group") {
        const round = currentRound(state);
        const answered = new Set(round.groupAnswers.map((a) => a.seatNo));
        const due = p.bots.filter((b) => !answered.has(b.seatNo) && b.at <= now).sort((a, b) => a.at - b.at)[0];
        if (due && due.at < p.deadline) {
          groupAnswer(state, due.seatNo, botChoice(state, questionOf(state, round.questionId), due.correct), due.at, events);
        } else if (now >= p.deadline) {
          endGroup(state, p.deadline, events);
        } else break;
      } else if (p.kind === "choosing") {
        const round = currentRound(state);
        if (p.botAt !== void 0 && now >= p.botAt) {
          const square = bestSquare(state, round.chooser);
          if (square) doSquare(state, [square], p.botAt, events);
          else {
            round.choiceDropped = true;
            startDisplay(state, p.botAt);
          }
        } else if (now >= p.deadline) {
          round.choiceDropped = true;
          events.push({ type: "choiceDropped", at: p.deadline, roundId: round.id, seatNo: round.chooser });
          startDisplay(state, p.deadline);
        } else break;
      } else if (p.kind === "burn") {
        if (now < p.until) break;
        finishBurn(state, p.until);
      } else if (p.kind === "display") {
        if (now < p.until) break;
        afterDisplay(state, p.until, events);
      } else if (p.kind === "paused") {
        if (now < p.until) break;
        state.paused = void 0;
        end(state, p.until, "cancelled", events);
      }
    }
    return { state, events };
  }
  var rejectTime = (input, at) => !validTime(at) || at < input.lastAt ? { state: clone(input), events: [], rejected: "bad_time" } : null;
  function answer(input, seatNo, choice, at) {
    const bad = rejectTime(input, at);
    if (bad) return bad;
    const { state, events } = tick(input, at);
    const round = currentRound(state);
    const p = state.phase;
    if (p.kind === "group" && round?.type === "group") {
      if (!seatOf(state, seatNo) || isBot(state, seatNo)) return { state, events, rejected: "not_your_turn" };
      if (round.groupAnswers.some((a) => a.seatNo === seatNo)) return { state, events, rejected: "already_answered" };
      if (!validChoice(questionOf(state, round.questionId), choice)) return { state, events, rejected: "bad_choice" };
      groupAnswer(state, seatNo, choice, at, events);
      return { state, events };
    }
    if (p.kind !== "answering" || !round) {
      const mine = round?.seatNo === seatNo;
      const rejected = mine && round?.answer !== void 0 ? "already_answered" : mine && round?.result === "timeout" ? "too_late" : "not_now";
      return { state, events, rejected };
    }
    if (round.seatNo !== seatNo || isBot(state, seatNo)) return { state, events, rejected: "not_your_turn" };
    if (!validChoice(questionOf(state, round.questionId), choice)) return { state, events, rejected: "bad_choice" };
    doAnswer(state, choice, at, events);
    return { state, events };
  }
  function choose(input, seatNo, pick2, at) {
    const bad = rejectTime(input, at);
    if (bad) return bad;
    const { state, events } = tick(input, at);
    const round = currentRound(state);
    if (state.phase.kind !== "choosing" || !round) return { state, events, rejected: "not_now" };
    if (round.chooser !== seatNo || isBot(state, seatNo)) return { state, events, rejected: "not_your_turn" };
    if (pick2?.kind === "box") {
      if ((state.boxes[String(seatNo)] ?? 0) <= 0) return { state, events, rejected: "no_box" };
      if (round.boardCard) return { state, events, rejected: "not_now" };
      doBox(state, at, events);
      return { state, events };
    }
    const centers = pick2?.kind === "square" && Array.isArray(pick2.centers) ? pick2.centers : [];
    const valid = centers.length === centersNeeded(round) && centers.every((c) => centerAllowed(state, c)) && new Set(centers.map((c) => `${c.row},${c.col}`)).size === centers.length;
    if (!valid) return { state, events, rejected: "bad_square" };
    doSquare(state, centers.map((c) => ({ row: c.row, col: c.col })), at, events);
    return { state, events };
  }
  function playCard(input, seatNo, cardId, target, at) {
    const bad = rejectTime(input, at);
    if (bad) return bad;
    const { state, events } = tick(input, at);
    const card = state.cards.find((c) => c.id === cardId && c.seatNo === seatNo && c.status === "held");
    if (!card) return { state, events, rejected: "no_card" };
    const round = currentRound(state);
    const reject = (r) => ({ state, events, rejected: r });
    if (cardBlock(state, seatNo, card)) return reject("card_not_now");
    switch (card.type) {
      case "burn":
        return reject("card_not_now");
      case "swap_question": {
        const next2 = drawQuestion(state);
        round.swappedOut = [...round.swappedOut ?? [], round.questionId];
        round.questionId = next2.id;
        round.deadline = at + state.times.answer;
        state.phase = { kind: "answering", deadline: round.deadline };
        break;
      }
      case "any_answer":
        round.anyAnswer = true;
        break;
      case "clear_squares": {
        const cells = Array.isArray(target?.cells) ? target.cells : [];
        const ok = cells.length === card.clearCount && new Set(cells.map((c) => `${c?.row},${c?.col}`)).size === cells.length && cells.every((c) => clearAllowed(state, c));
        if (!ok) return reject("bad_target");
        const changes = cells.map((c) => {
          const i = index(state.boardSize, c.row, c.col);
          const from = state.board[i];
          state.board[i] = 0;
          return { index: i, from };
        });
        spend(state, card, round, at, events);
        openBurnWindows(state, seatNo, changes, at, { kind: "answering", remaining: round.deadline - at }, events);
        return { state, events };
      }
      case "fortify": {
        const c = target?.center;
        if (!c || !inBoard(state.boardSize, c.row, c.col)) return reject("bad_target");
        state.fortsCreated++;
        state.fortifications.push({
          id: state.fortsCreated,
          center: { row: c.row, col: c.col },
          ownerSeat: seatNo,
          createdRound: round.id,
          ownerTurnsSince: 0
        });
        break;
      }
      case "double_cross":
      case "place_anywhere":
        round.boardCard = card.type;
        break;
    }
    spend(state, card, round, at, events);
    return { state, events };
  }
  function cardBlock(state, seatNo, card) {
    const round = currentRound(state);
    const p = state.phase;
    switch (card.type) {
      case "burn":
        return "reaction";
      case "double_cross":
      case "place_anywhere":
        if (p.kind !== "choosing" || round?.chooser !== seatNo) return "board_window";
        return round.boardCard ? "one_board_card" : null;
      default:
        if (p.kind === "group") return "group";
        if (p.kind !== "answering" || round?.type !== "turn" || round.seatNo !== seatNo || round.answer !== void 0) {
          return "question_window";
        }
        return card.type === "swap_question" && round.anyAnswer ? "swap_locked" : null;
    }
  }
  function centerAllowed(state, c) {
    const anywhere = currentRound(state)?.boardCard === "place_anywhere";
    return canCenter(state.board, state.boardSize, c?.row, c?.col, fortified(state), anywhere);
  }
  var centersNeeded = (round) => round.boardCard === "double_cross" ? 2 : 1;
  function boxAllowed(state, seatNo) {
    const round = currentRound(state);
    return state.phase.kind === "choosing" && round?.chooser === seatNo && !isBot(state, seatNo) && !round.boardCard && (state.boxes[String(seatNo)] ?? 0) > 0;
  }
  function clearAllowed(state, c) {
    if (!inBoard(state.boardSize, c?.row, c?.col)) return false;
    const i = index(state.boardSize, c.row, c.col);
    return state.board[i] !== 0 && !fortified(state).has(i);
  }
  function spend(state, card, round, at, events) {
    card.status = "spent";
    round.played = [...round.played ?? [], card.type];
    events.push({ type: "cardPlayed", at, roundId: round.id, seatNo: card.seatNo, card: card.type });
  }
  function decideBurn(input, seatNo, burn, at) {
    const bad = rejectTime(input, at);
    if (bad) return bad;
    const { state, events } = tick(input, at);
    const p = state.phase;
    if (p.kind !== "burn") return { state, events, rejected: "not_now" };
    const w = p.windows.find((x) => x.seatNo === seatNo && !x.decided);
    if (!w) return { state, events, rejected: "not_your_turn" };
    if (burn === true) {
      const card = heldCards(state, seatNo).find((c) => c.type === "burn");
      if (!card) return { state, events, rejected: "no_card" };
      for (const c of w.cells) state.board[index(state.boardSize, c.row, c.col)] = seatNo;
      card.status = "spent";
      events.push({ type: "burned", at, seatNo, restored: w.cells.length });
      w.decided = "burn";
    } else {
      w.decided = "skip";
    }
    if (p.windows.every((x) => x.decided)) finishBurn(state, at);
    return { state, events };
  }
  function wakeAt(state) {
    const p = state.phase;
    switch (p.kind) {
      case "countdown":
      case "display":
      case "burn":
      case "paused":
        return p.until;
      case "answering":
      case "choosing":
        return p.botAt !== void 0 ? Math.min(p.deadline, p.botAt) : p.deadline;
      case "group":
        return Math.min(p.deadline, ...p.bots.filter((b) => !currentRound(state)?.groupAnswers?.some((a) => a.seatNo === b.seatNo)).map((b) => b.at));
      case "ended":
        return null;
    }
  }
  var PAUSE_MS = 12e4;
  var humansLeft = (state) => state.seats.filter((s) => !s.isBot).map((s) => s.seatNo);
  function pause(state, at, events) {
    if (state.phase.kind === "ended" || state.phase.kind === "paused") return;
    state.paused = { at, phase: clone(state.phase) };
    state.phase = { kind: "paused", until: at + PAUSE_MS };
    events.push({ type: "paused", at });
  }
  function resume(state, at, events) {
    if (state.phase.kind !== "paused" || !state.paused) return;
    const delta = at - state.paused.at;
    const p = state.paused.phase;
    const shift = (t) => t + delta;
    switch (p.kind) {
      case "countdown":
      case "display":
        p.until = shift(p.until);
        break;
      case "burn":
        p.until = shift(p.until);
        break;
      case "answering":
      case "choosing":
        p.deadline = shift(p.deadline);
        if (p.botAt !== void 0) p.botAt = shift(p.botAt);
        break;
      case "group":
        p.deadline = shift(p.deadline);
        for (const b of p.bots) b.at = shift(b.at);
        break;
    }
    const round = currentRound(state);
    if (round && round.result === void 0) round.deadline = shift(round.deadline);
    if (round?.displayUntil !== void 0 && p.kind === "display") round.displayUntil = shift(round.displayUntil);
    state.phase = p;
    state.paused = void 0;
    events.push({ type: "resumed", at });
  }
  function setPresence(input, seatNo, connected, at) {
    const bad = rejectTime(input, at);
    if (bad) return bad;
    const { state, events } = tick(input, at);
    if (!seatOf(state, seatNo) || isBot(state, seatNo)) return { state, events, rejected: "not_human" };
    if (state.phase.kind === "ended") return { state, events };
    const away = new Set(state.away ?? []);
    if (connected) away.delete(seatNo);
    else away.add(seatNo);
    state.away = [...away].sort((a, b) => a - b);
    const p = state.phase;
    if (connected) {
      resume(state, at, events);
    } else {
      if (p.kind === "burn") {
        for (const w of p.windows) if (w.seatNo === seatNo && !w.decided) w.decided = "skip";
        if (p.windows.every((w) => w.decided)) finishBurn(state, at);
      } else if (p.kind === "choosing" && currentRound(state)?.chooser === seatNo && p.botAt === void 0) {
        p.botAt = planChoose(state, at, p.deadline);
      }
      if (humansLeft(state).every((h) => away.has(h))) pause(state, at, events);
    }
    return { state, events };
  }
  function withdraw(input, seatNo, at) {
    const bad = rejectTime(input, at);
    if (bad) return bad;
    const { state, events } = tick(input, at);
    const seat = seatOf(state, seatNo);
    if (!seat || seat.isBot) return { state, events, rejected: "not_human" };
    if (state.phase.kind === "ended") return { state, events, rejected: "not_now" };
    seat.isBot = true;
    state.withdrawn = [...state.withdrawn ?? [], seatNo];
    state.away = (state.away ?? []).filter((s) => s !== seatNo);
    events.push({ type: "withdrew", at, seatNo });
    const round = currentRound(state);
    const p = state.phase.kind === "paused" && state.paused ? state.paused.phase : state.phase;
    if (p.kind === "answering" && round?.seatNo === seatNo && round.answer === void 0 && p.botAt === void 0) {
      const plan = planAnswer(state, at, p.deadline);
      p.botAt = Math.max(plan.botAt, at);
      p.botCorrect = plan.correct;
    } else if (p.kind === "choosing" && round?.chooser === seatNo && p.botAt === void 0) {
      p.botAt = planChoose(state, at, p.deadline);
    } else if (p.kind === "group" && !round?.groupAnswers?.some((a) => a.seatNo === seatNo)) {
      const plan = planAnswer(state, at, p.deadline);
      p.bots.push({ seatNo, at: Math.max(plan.botAt, at), correct: plan.correct });
    } else if (p.kind === "burn") {
      for (const w of p.windows) if (w.seatNo === seatNo && !w.decided) w.decided = "skip";
      if (state.phase.kind === "burn" && p.windows.every((w) => w.decided)) finishBurn(state, at);
    }
    if (humansLeft(state).length === 0) {
      state.paused = void 0;
      end(state, at, "cancelled", events);
    } else if (humansLeft(state).every((h) => state.away.includes(h))) {
      pause(state, at, events);
    }
    return { state, events };
  }

  // server/engine/training.ts
  function questionsNeeded(size) {
    const turns = size * Math.max(cyclesFor(size, true), cyclesFor(size, false));
    return turns + 5 + size * BOXES_PER_SEAT;
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
  function view(state, forSeat) {
    const p = state.phase;
    const phase = p.kind === "answering" ? { kind: "answering", deadline: p.deadline } : p.kind === "group" ? { kind: "group", deadline: p.deadline } : p.kind === "choosing" ? { kind: "choosing", deadline: p.deadline } : p.kind === "burn" ? { kind: "burn", until: p.until, windows: p.windows.map((w) => ({ ...w, cells: [...w.cells] })) } : p;
    const r = currentRound(state);
    let round;
    if (r) {
      const q = questionOf(state, r.questionId);
      const over = r.result !== void 0;
      const box = r.boxCard !== void 0 ? state.cards.find((c) => c.id === r.boxCard) : void 0;
      round = {
        id: r.id,
        type: r.type,
        deadline: r.deadline,
        ...r.seatNo !== void 0 ? { seatNo: r.seatNo } : {},
        question: {
          id: q.id,
          type: q.type,
          text: q.text,
          ...q.type === "mcq" ? { options: [...q.options] } : {},
          ...over ? { correct: q.correct } : {}
        },
        ...r.answer !== void 0 ? { answer: r.answer } : {},
        ...r.result ? { result: r.result } : {},
        ...r.chooser !== void 0 && over ? { chooser: r.chooser } : {},
        ...r.choice ? { choice: r.choice } : {},
        ...r.centers ? { centers: r.centers.map((c) => ({ ...c })) } : {},
        ...r.choiceDropped ? { choiceDropped: true } : {},
        ...box ? { boxCard: { type: box.type, ...box.clearCount ? { clearCount: box.clearCount } : {} } } : {},
        ...r.played ? { played: [...r.played] } : {},
        ...r.anyAnswer ? { anyAnswer: true } : {},
        ...r.boardCard ? { boardCard: r.boardCard } : {}
      };
      if (p.kind === "choosing") {
        round.centersNeeded = centersNeeded(r);
        round.boxAllowed = boxAllowed(state, r.chooser);
      }
      if (r.type === "group") {
        if (over) {
          round.groupAnswers = r.groupAnswers.map((a) => ({ seatNo: a.seatNo, choice: a.choice, correct: a.correct }));
          if (r.winnerSeat !== void 0) round.winnerSeat = r.winnerSeat;
        } else {
          round.answeredSeats = r.groupAnswers.map((a) => a.seatNo);
          const mine = r.groupAnswers.find((a) => a.seatNo === forSeat);
          if (mine) round.myAnswer = mine.choice;
        }
      }
    }
    return {
      size: state.size,
      boardSize: state.boardSize,
      cycle: state.cycle,
      cyclesTotal: state.cyclesTotal,
      groupEnabled: state.groupEnabled,
      times: { ...state.times },
      board: [...state.board],
      seats: state.seats.map((s) => ({
        ...s,
        persona: { ...s.persona },
        squares: squaresOf(state.board, s.seatNo),
        boxesLeft: state.boxes[String(s.seatNo)] ?? 0,
        ...state.away?.includes(s.seatNo) ? { away: true } : {},
        ...state.withdrawn?.includes(s.seatNo) ? { withdrawn: true } : {},
        cards: heldCards(state, s.seatNo).map((c) => {
          const blocked = s.seatNo === forSeat ? cardBlock(state, s.seatNo, c) : null;
          return { id: c.id, type: c.type, ...c.clearCount ? { clearCount: c.clearCount } : {}, ...blocked ? { blocked } : {} };
        })
      })),
      order: orderOf(state, Math.min(state.cycle, state.cyclesTotal)),
      fortifications: state.fortifications.map((f) => ({
        id: f.id,
        ownerSeat: f.ownerSeat,
        center: { ...f.center },
        cells: crossCells(state.boardSize, f.center.row, f.center.col),
        turnsLeft: 3 - f.ownerTurnsSince
      })),
      phase,
      ...round ? { round } : {},
      ...p.kind === "ended" ? { ranking: ranking(state.board, state.seats.map((s) => s.seatNo)) } : {},
      ...targetsFor(state, forSeat)
    };
  }
  function targetsFor(state, forSeat) {
    if (forSeat === void 0) return {};
    const cells = state.board.map((_, i) => ({ row: Math.floor(i / state.boardSize), col: i % state.boardSize }));
    const indices = (ok) => cells.flatMap((c, i) => ok(c) ? [i] : []);
    const r = currentRound(state);
    const targets = {};
    if (state.phase.kind === "choosing" && r?.chooser === forSeat) targets.centers = indices((c) => centerAllowed(state, c));
    if (heldCards(state, forSeat).some((c) => c.type === "clear_squares" && !cardBlock(state, forSeat, c))) {
      targets.clear = indices((c) => clearAllowed(state, c));
    }
    return Object.keys(targets).length ? { targets } : {};
  }

  // server/engine/index.ts
  var out = (r, viewer) => JSON.stringify({
    state: JSON.stringify(r.state),
    view: view(r.state, viewer),
    events: r.events,
    ...r.rejected ? { rejected: r.rejected } : {}
  });
  var bridge = {
    createTraining: (setupJson, now, viewer) => out(createTraining(JSON.parse(setupJson), now), viewer),
    tick: (stateJson, now, viewer) => out(tick(JSON.parse(stateJson), now), viewer),
    answer: (stateJson, seatNo, choiceJson, now) => out(answer(JSON.parse(stateJson), seatNo, JSON.parse(choiceJson), now), seatNo),
    choose: (stateJson, seatNo, pickJson, now) => out(choose(JSON.parse(stateJson), seatNo, JSON.parse(pickJson), now), seatNo),
    playCard: (stateJson, seatNo, cardId, targetJson, now) => out(playCard(JSON.parse(stateJson), seatNo, cardId, JSON.parse(targetJson), now), seatNo),
    decideBurn: (stateJson, seatNo, burn, now) => out(decideBurn(JSON.parse(stateJson), seatNo, burn, now), seatNo),
    // قواعد يحتاجها العرض قبل الحكم، من المحرّك نفسه لا مكرّرة في سويفت
    crossCells: (boardSize, row, col) => JSON.stringify(crossCells(boardSize, row, col)),
    suggestedBoard: (size) => suggestedBoard(size),
    questionsNeeded: (size) => questionsNeeded(size)
  };
  return __toCommonJS(index_exports);
})();
