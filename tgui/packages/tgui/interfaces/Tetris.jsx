// THIS IS A META UI FILE
import { Component } from 'react';
import { Box, Button, KeyListener, Section, Stack } from 'tgui-core/components';
import { acquireHotKey, releaseHotKey } from 'tgui-core/hotkeys';
import {
  KEY_C,
  KEY_DOWN,
  KEY_LEFT,
  KEY_RIGHT,
  KEY_SPACE,
  KEY_UP,
  KEY_X,
  KEY_Z,
} from 'tgui-core/keycodes';

import { useBackend } from '../backend';
import { Window } from '../layouts';

const BOARD_W = 10;
const BOARD_H = 20;
const CELL_PX = 22;

const DAS_MS = 170;
const ARR_MS = 45;
const SOFT_DROP_MS = 40;
const LOCK_DELAY_MS = 500;
const MAX_LOCK_RESETS = 15;
// How often the active player's client pushes a board snapshot for spectators to render.
const SYNC_MS = 200;

// Must match TETRIS_IDLE/TETRIS_PLAYING/TETRIS_GAMEOVER in
// modular_zzmeta/modules/tetris/code/tetris.dm.
const TETRIS_IDLE = 0;
const TETRIS_PLAYING = 1;
const TETRIS_GAMEOVER = 2;

const MODES = [
  { key: 'marathon', label: 'Marathon' },
  { key: 'sprint', label: 'Sprint (40L)' },
  { key: 'blitz', label: 'Blitz (2min)' },
  { key: 'garbage', label: 'Garbage Race' },
];
const SPRINT_TARGET_LINES = 40;
const BLITZ_DURATION_MS = 2 * 60 * 1000;
const GARBAGE_ROWS = 13;
const GARBAGE_TARGET_LINES = 13;
// How often the on-screen clock (elapsed for sprint/garbage, countdown for blitz) refreshes.
// Independent of SYNC_MS since spectators don't need this, only the local player's own UI.
const STATUS_UPDATE_MS = 250;

// I is a 4x4 box (it spans the box's full width/height in every orientation, so it has no
// off-center cells to drift). O is a plain 2x2 (a rotation is always a no-op on a symmetric
// square). The rest are 3x3 boxes with the shape's pivot cell at the true center [1][1], so
// rotateMatrix spins them in place instead of shunting them across the board. A 4x4 box with
// the shape sitting in rows 0-1 (as these used to be defined) rotates around the box's corner
// rather than the piece's own center, which visibly relocates the piece by a cell or two on
// every press.
const SHAPES = {
  I: [
    [0, 0, 0, 0],
    [1, 1, 1, 1],
    [0, 0, 0, 0],
    [0, 0, 0, 0],
  ],
  O: [
    [1, 1],
    [1, 1],
  ],
  T: [
    [0, 1, 0],
    [1, 1, 1],
    [0, 0, 0],
  ],
  S: [
    [0, 1, 1],
    [1, 1, 0],
    [0, 0, 0],
  ],
  Z: [
    [1, 1, 0],
    [0, 1, 1],
    [0, 0, 0],
  ],
  J: [
    [1, 0, 0],
    [1, 1, 1],
    [0, 0, 0],
  ],
  L: [
    [0, 0, 1],
    [1, 1, 1],
    [0, 0, 0],
  ],
};

const COLORS = {
  I: '#31c7ef',
  O: '#f7d308',
  T: '#ad4d9c',
  S: '#42b642',
  Z: '#ef2029',
  J: '#5a65ad',
  L: '#ef7921',
  GARBAGE: '#5c5c5c',
};

const PIECE_TYPES = Object.keys(SHAPES);

// Simple wall kick attempts, tried in order after a bare rotation fails.
const KICKS = [0, -1, 1, -2, 2];

const rotateMatrix = (matrix, dir) => {
  const size = matrix.length;
  const rotated = [];
  for (let y = 0; y < size; y++) {
    rotated.push(new Array(size).fill(0));
  }
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      if (dir > 0) {
        rotated[x][size - 1 - y] = matrix[y][x];
      } else {
        rotated[size - 1 - x][y] = matrix[y][x];
      }
    }
  }
  return rotated;
};

const makeEmptyBoard = () =>
  Array.from({ length: BOARD_H }, () => new Array(BOARD_W).fill(null));

// Garbage Race starting board: the bottom GARBAGE_ROWS rows are filled solid except for one
// random gap column each (the standard Tetris "garbage line" shape), so every row needs its
// own gap filled by an actual piece before it can clear.
const makeGarbageBoard = () => {
  const board = makeEmptyBoard();
  for (let i = 0; i < GARBAGE_ROWS; i++) {
    const y = BOARD_H - 1 - i;
    const hole = Math.floor(Math.random() * BOARD_W);
    for (let x = 0; x < BOARD_W; x++) {
      if (x !== hole) {
        board[y][x] = 'GARBAGE';
      }
    }
  }
  return board;
};

// Fisher-Yates shuffle of one copy of each piece type ("7-bag" randomizer), so runs
// of the same piece are impossible and every 7 pieces contains one of each.
const makeBag = () => {
  const bag = [...PIECE_TYPES];
  for (let i = bag.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [bag[i], bag[j]] = [bag[j], bag[i]];
  }
  return bag;
};

const collides = (board, matrix, px, py) => {
  for (let y = 0; y < matrix.length; y++) {
    for (let x = 0; x < matrix[y].length; x++) {
      if (!matrix[y][x]) {
        continue;
      }
      const bx = px + x;
      const by = py + y;
      if (bx < 0 || bx >= BOARD_W || by >= BOARD_H) {
        return true;
      }
      if (by < 0) {
        continue;
      }
      if (board[by][bx]) {
        return true;
      }
    }
  }
  return false;
};

const dropDistance = (board, matrix, x, y) => {
  let dist = 0;
  while (!collides(board, matrix, x, y + dist + 1)) {
    dist++;
  }
  return dist;
};

// Where the current piece would land on an instant hard drop, for the ghost outline. Returns
// null once the piece is already resting there (nothing to preview).
const buildGhostBoard = (board, current) => {
  if (!current) {
    return null;
  }
  const dist = dropDistance(board, current.matrix, current.x, current.y);
  if (dist === 0) {
    return null;
  }
  const ghost = makeEmptyBoard();
  const ghostY = current.y + dist;
  for (let y = 0; y < current.matrix.length; y++) {
    for (let x = 0; x < current.matrix[y].length; x++) {
      if (!current.matrix[y][x]) {
        continue;
      }
      const by = ghostY + y;
      const bx = current.x + x;
      if (by >= 0 && by < BOARD_H && bx >= 0 && bx < BOARD_W) {
        ghost[by][bx] = current.type;
      }
    }
  }
  return ghost;
};

const mergePiece = (board, matrix, px, py, type) => {
  const next = board.map((row) => row.slice());
  for (let y = 0; y < matrix.length; y++) {
    for (let x = 0; x < matrix[y].length; x++) {
      if (!matrix[y][x]) {
        continue;
      }
      const by = py + y;
      const bx = px + x;
      if (by >= 0 && by < BOARD_H && bx >= 0 && bx < BOARD_W) {
        next[by][bx] = type;
      }
    }
  }
  return next;
};

const clearLines = (board) => {
  const remaining = board.filter((row) => row.some((cell) => !cell));
  const cleared = BOARD_H - remaining.length;
  while (remaining.length < BOARD_H) {
    remaining.unshift(new Array(BOARD_W).fill(null));
  }
  return { board: remaining, cleared };
};

const LINE_SCORES = [0, 100, 300, 500, 800];

const gravityMs = (level) => Math.max(120, 900 - (level - 1) * 70);

const formatTime = (ms) => {
  const totalSeconds = Math.max(0, ms) / 1000;
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, '0')}:${seconds.toFixed(1).padStart(4, '0')}`;
};

// Server-tracked bests (sprint_best_ds/garbage_best_ds) are in deciseconds, not ms.
const formatDs = (ds) => formatTime(ds * 100);

const spawnFromType = (type) => ({
  type,
  matrix: SHAPES[type].map((row) => row.slice()),
  x: Math.floor((BOARD_W - SHAPES[type][0].length) / 2),
  y: 0,
});

const buildDisplayBoard = (board, current) => {
  const displayBoard = board.map((row) => row.slice());
  if (current) {
    for (let y = 0; y < current.matrix.length; y++) {
      for (let x = 0; x < current.matrix[y].length; x++) {
        if (!current.matrix[y][x]) {
          continue;
        }
        const by = current.y + y;
        const bx = current.x + x;
        if (by >= 0 && by < BOARD_H && bx >= 0 && bx < BOARD_W) {
          displayBoard[by][bx] = current.type;
        }
      }
    }
  }
  return displayBoard;
};

// Piece boxes vary in size (2x2 O, 3x3 JLSTZT, 4x4 I - see SHAPES), but the Hold/Next previews
// should all look the same footprint, so every piece is centered within a fixed 4x4 frame here.
const MINI_GRID = 4;

const renderMiniPiece = (type) => {
  const cells = [];
  const matrix = type ? SHAPES[type] : null;
  const size = matrix ? matrix.length : 0;
  const offset = Math.floor((MINI_GRID - size) / 2);
  for (let y = 0; y < MINI_GRID; y++) {
    for (let x = 0; x < MINI_GRID; x++) {
      const my = y - offset;
      const mx = x - offset;
      const filled = matrix && my >= 0 && my < size && matrix[my]?.[mx];
      cells.push(
        <Box
          key={`${x}-${y}`}
          width="12px"
          height="12px"
          style={{
            'background-color': filled ? COLORS[type] : 'transparent',
            outline: filled ? '1px solid rgba(0,0,0,0.4)' : 'none',
          }}
        />,
      );
    }
  }
  return (
    <Box
      style={{
        display: 'inline-grid',
        'grid-template-columns': `repeat(${MINI_GRID}, 12px)`,
        'grid-template-rows': `repeat(${MINI_GRID}, 12px)`,
      }}
    >
      {cells}
    </Box>
  );
};

const BoardGrid = ({ board, ghost, overlay }) => (
  <Box
    style={{
      position: 'relative',
      display: 'inline-grid',
      'grid-template-columns': `repeat(${BOARD_W}, ${CELL_PX}px)`,
      'grid-template-rows': `repeat(${BOARD_H}, ${CELL_PX}px)`,
      gap: '1px',
      'background-color': 'rgba(0,0,0,0.3)',
    }}
  >
    {board.map((row, y) =>
      row.map((cell, x) => {
        const ghostType = !cell && ghost?.[y][x];
        return (
          <Box
            key={`${x}-${y}`}
            style={{
              'background-color': cell ? COLORS[cell] : 'rgba(255,255,255,0.03)',
              'box-sizing': 'border-box',
              border: ghostType ? `2px solid ${COLORS[ghostType]}` : 'none',
            }}
          />
        );
      }),
    )}
    {overlay && (
      <Box
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          display: 'flex',
          'flex-direction': 'column',
          'align-items': 'center',
          'justify-content': 'center',
          'background-color': 'rgba(0,0,0,0.6)',
        }}
      >
        {overlay}
      </Box>
    )}
  </Box>
);

const KEYBINDS = [
  ['← / →', 'Move'],
  ['↓', 'Soft drop'],
  ['Space', 'Hard drop'],
  ['↑ / X', 'Rotate CW'],
  ['Z', 'Rotate CCW'],
  ['C', 'Hold'],
];

const KeybindsHelpButton = () => (
  <Button
    icon="circle-question"
    color="transparent"
    tooltipPosition="bottom"
    tooltip={
      <Box>
        {KEYBINDS.map(([key, action]) => (
          <Box key={key}>
            <b>{key}</b> {action}
          </Box>
        ))}
        <Box color="label" mt={0.5}>
          On-screen buttons work the same either way.
        </Box>
      </Box>
    }
  />
);

const ModeSelect = ({ mode, onSelect }) => (
  <Stack vertical>
    {MODES.map((m) => (
      <Stack.Item key={m.key}>
        <Button
          fluid
          selected={mode === m.key}
          content={m.label}
          onClick={() => onSelect(m.key)}
        />
      </Stack.Item>
    ))}
  </Stack>
);

// Shared between the player's own Stats panel and the spectator's, so the two can't drift.
const StatsBlock = ({
  mode,
  score,
  lines,
  level,
  statusMs,
  highScore,
  blitzHighScore,
  sprintBestDs,
  garbageBestDs,
  tickets,
}) => (
  <>
    {mode === 'blitz' && (
      <>
        <Box>
          <b>Time Left:</b> {formatTime(statusMs)}
        </Box>
        <Box>
          <b>Score:</b> {score}
        </Box>
        <Box>
          <b>Best Score:</b> {blitzHighScore}
        </Box>
      </>
    )}
    {mode === 'sprint' && (
      <>
        <Box>
          <b>Time:</b> {formatTime(statusMs)}
        </Box>
        <Box>
          <b>Lines:</b> {lines}/{SPRINT_TARGET_LINES}
        </Box>
        <Box>
          <b>Best Time:</b> {sprintBestDs ? formatDs(sprintBestDs) : '--:--'}
        </Box>
      </>
    )}
    {mode === 'garbage' && (
      <>
        <Box>
          <b>Time:</b> {formatTime(statusMs)}
        </Box>
        <Box>
          <b>Lines:</b> {lines}/{GARBAGE_TARGET_LINES}
        </Box>
        <Box>
          <b>Best Time:</b> {garbageBestDs ? formatDs(garbageBestDs) : '--:--'}
        </Box>
      </>
    )}
    {mode === 'marathon' && (
      <>
        <Box>
          <b>Score:</b> {score}
        </Box>
        <Box>
          <b>Lines:</b> {lines}
        </Box>
        <Box>
          <b>Level:</b> {level}
        </Box>
        <Box>
          <b>High Score:</b> {highScore}
        </Box>
      </>
    )}
    <Box>
      <b>Tickets:</b> {tickets}
    </Box>
  </>
);

class TetrisGame extends Component {
  constructor(props) {
    super(props);

    this.bag = [];
    this.animationId = null;
    this.lastFrame = null;
    this.dropAccumulator = 0;
    this.grounded = false;
    this.lockTimer = LOCK_DELAY_MS;
    this.lockResets = 0;
    this.dasDirection = null;
    this.dasElapsed = 0;
    this.arrElapsed = 0;
    this.softDropHeld = false;
    this.pressedKeys = new Set();
    this.reported = false;
    this.syncAccumulator = 0;
    this.statusAccumulator = 0;
    this.gameStartTs = 0;

    this.state = this.buildInitialState(false);

    this.updateAnimation = this.updateAnimation.bind(this);
    this.handleKeyDown = this.handleKeyDown.bind(this);
    this.handleKeyUp = this.handleKeyUp.bind(this);
    this.startNewGame = this.startNewGame.bind(this);
    this.selectMode = this.selectMode.bind(this);
    this.startMoveLeft = this.startMoveLeft.bind(this);
    this.stopMoveLeft = this.stopMoveLeft.bind(this);
    this.startMoveRight = this.startMoveRight.bind(this);
    this.stopMoveRight = this.stopMoveRight.bind(this);
    this.startSoftDrop = this.startSoftDrop.bind(this);
    this.stopSoftDrop = this.stopSoftDrop.bind(this);
    this.hardDrop = this.hardDrop.bind(this);
    this.rotateCW = this.rotateCW.bind(this);
    this.rotateCCW = this.rotateCCW.bind(this);
    this.holdPiece = this.holdPiece.bind(this);
    this.pushSync = this.pushSync.bind(this);
  }

  buildSnapshot() {
    const { board, current, hold, queue, score, lines, level, mode, statusMs } = this.state;
    return {
      board: buildDisplayBoard(board, current),
      hold,
      queue,
      score,
      lines,
      level,
      mode,
      statusMs,
    };
  }

  pushSync(sfx) {
    this.props.onSync?.(this.buildSnapshot(), sfx);
  }

  buildInitialState(playing) {
    return {
      phase: playing ? 'playing' : 'idle',
      mode: 'marathon',
      board: makeEmptyBoard(),
      current: null,
      queue: [],
      hold: null,
      canHold: true,
      score: 0,
      lines: 0,
      level: 1,
      statusMs: 0,
      completed: false,
    };
  }

  selectMode(modeKey) {
    if (this.state.phase === 'playing') {
      return;
    }
    this.setState({ mode: modeKey });
  }

  componentDidMount() {
    [KEY_C, KEY_X, KEY_Z].forEach((code) => {
      acquireHotKey(code);
    });
  }

  componentWillUnmount() {
    [KEY_C, KEY_X, KEY_Z].forEach((code) => {
      releaseHotKey(code);
    });
    if (this.animationId) {
      window.cancelAnimationFrame(this.animationId);
    }
  }

  nextFromQueue(queue) {
    const nextQueue = queue.slice(1);
    while (nextQueue.length < 3) {
      if (!this.bag.length) {
        this.bag = makeBag();
      }
      nextQueue.push(this.bag.shift());
    }
    return nextQueue;
  }

  startNewGame() {
    const { mode } = this.state;
    this.props.onNewGame();
    this.bag = makeBag();
    const queue = [this.bag.shift(), this.bag.shift(), this.bag.shift()];
    while (!this.bag.length) {
      this.bag = makeBag();
    }
    const current = spawnFromType(queue[0]);
    const nextQueue = this.nextFromQueue(queue);

    this.grounded = false;
    this.lockTimer = LOCK_DELAY_MS;
    this.lockResets = 0;
    this.dropAccumulator = 0;
    this.statusAccumulator = 0;
    this.reported = false;
    this.gameStartTs = Date.now();

    this.setState(
      {
        phase: 'playing',
        board: mode === 'garbage' ? makeGarbageBoard() : makeEmptyBoard(),
        current,
        queue: nextQueue,
        hold: null,
        canHold: true,
        score: 0,
        lines: 0,
        level: 1,
        statusMs: mode === 'blitz' ? BLITZ_DURATION_MS : 0,
        completed: false,
      },
      () => {
        this.lastFrame = null;
        this.syncAccumulator = 0;
        this.pushSync();
        if (!this.animationId) {
          this.animationId = window.requestAnimationFrame(this.updateAnimation);
        }
      },
    );
  }

  // Single reporting path for every way a run can end: topping out (completed = false), or
  // hitting the mode's actual goal, meaning 40 lines, the garbage cleared, or blitz's clock
  // running out (completed = true in all three of those cases).
  finishRun(completed) {
    if (this.animationId) {
      window.cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
    if (!this.reported) {
      this.reported = true;
      this.props.onGameOver(this.state.score, this.state.lines, this.state.mode, completed);
    }
    this.setState({ phase: 'gameover', completed });
  }

  spawnNext() {
    this.setState((prevState) => {
      const current = spawnFromType(prevState.queue[0]);
      const queue = this.nextFromQueue(prevState.queue);
      if (collides(prevState.board, current.matrix, current.x, current.y)) {
        window.setTimeout(() => this.finishRun(false), 0);
        return { current: null, queue };
      }
      this.grounded = false;
      this.lockTimer = LOCK_DELAY_MS;
      this.lockResets = 0;
      return { current, queue, canHold: true };
    });
  }

  // `pieceOverride`, when given, is locked instead of re-reading this.state.current, and
  // `bonusScore` (the hard-drop distance bonus) is folded into the same setState call rather
  // than applied separately beforehand - see hardDrop() for why both of those matter.
  lockCurrent(pieceOverride, bonusScore = 0) {
    const { board, level, mode } = this.state;
    const current = pieceOverride || this.state.current;
    if (!current) {
      return;
    }
    const merged = mergePiece(board, current.matrix, current.x, current.y, current.type);
    const { board: cleared, cleared: clearedCount } = clearLines(merged);
    const scoreGain = LINE_SCORES[clearedCount] * level + bonusScore;
    const totalLines = this.state.lines + clearedCount;
    const newLevel = Math.floor(totalLines / 10) + 1;
    const sfx = clearedCount >= 4 ? 'tetris' : clearedCount > 0 ? 'clear' : 'lock';

    const targetLines =
      mode === 'sprint' ? SPRINT_TARGET_LINES : mode === 'garbage' ? GARBAGE_TARGET_LINES : null;
    const objectiveComplete = targetLines !== null && totalLines >= targetLines;

    this.setState(
      {
        board: cleared,
        score: this.state.score + scoreGain,
        lines: totalLines,
        level: newLevel,
        current: null,
      },
      () => {
        this.pushSync(sfx);
        if (objectiveComplete) {
          this.finishRun(true);
        } else {
          this.spawnNext();
        }
      },
    );
  }

  tryMove(dx, dy) {
    const { board, current } = this.state;
    if (!current) {
      return false;
    }
    const nx = current.x + dx;
    const ny = current.y + dy;
    if (collides(board, current.matrix, nx, ny)) {
      return false;
    }
    this.setState({ current: { ...current, x: nx, y: ny } });
    this.updateGroundedState(board, current.matrix, nx, ny);
    return true;
  }

  // A move/rotate can slide the piece off whatever ledge it was resting on into open space
  // below. Gravity must resume immediately instead of keeping the stale "grounded" flag from
  // before the move, otherwise the lock timer keeps counting down against the old position
  // and the piece locks floating in mid-air once it expires.
  updateGroundedState(board, matrix, x, y) {
    const stillGrounded = collides(board, matrix, x, y + 1);
    if (!stillGrounded) {
      this.grounded = false;
      return;
    }
    if (this.grounded) {
      if (this.lockResets < MAX_LOCK_RESETS) {
        this.lockTimer = LOCK_DELAY_MS;
        this.lockResets++;
      }
    } else {
      this.grounded = true;
      this.lockTimer = LOCK_DELAY_MS;
      this.lockResets = 0;
    }
  }

  rotate(dir) {
    const { board, current } = this.state;
    if (!current) {
      return;
    }
    const rotated = rotateMatrix(current.matrix, dir);
    for (const kick of KICKS) {
      if (!collides(board, rotated, current.x + kick, current.y)) {
        const nx = current.x + kick;
        this.setState({
          current: { ...current, matrix: rotated, x: nx },
        });
        this.updateGroundedState(board, rotated, nx, current.y);
        return;
      }
    }
  }

  rotateCW() {
    this.rotate(1);
  }

  rotateCCW() {
    this.rotate(-1);
  }

  // Locks synchronously off a locally-computed piece instead of going through a setState
  // callback. Under lag, a keydown for a horizontal move can land in the gap between an
  // earlier version's setState call and its callback firing, changing this.state.current.x to
  // something the drop distance was never actually collision-checked against, so the piece
  // would lock into a column it never validated (visually landing next to where it should
  // have, sometimes overlapping the stack). Reading state once and finishing the lock in the
  // same synchronous call closes that window.
  hardDrop() {
    const { board, current } = this.state;
    if (!current) {
      return;
    }
    const dist = dropDistance(board, current.matrix, current.x, current.y);
    this.lockCurrent({ ...current, y: current.y + dist }, dist * 2);
  }

  holdPiece() {
    const { current, hold, canHold, board } = this.state;
    if (!current || !canHold) {
      return;
    }
    if (hold === null) {
      this.setState({ hold: current.type, current: null, canHold: false }, () =>
        this.spawnNext(),
      );
      return;
    }
    const swapped = spawnFromType(hold);
    if (collides(board, swapped.matrix, swapped.x, swapped.y)) {
      return;
    }
    this.grounded = false;
    this.lockTimer = LOCK_DELAY_MS;
    this.lockResets = 0;
    this.setState({ current: swapped, hold: current.type, canHold: false });
  }

  startMoveLeft() {
    if (this.dasDirection === 'left') {
      return;
    }
    this.dasDirection = 'left';
    this.dasElapsed = 0;
    this.arrElapsed = 0;
    this.tryMove(-1, 0);
  }

  stopMoveLeft() {
    if (this.dasDirection === 'left') {
      this.dasDirection = null;
    }
  }

  startMoveRight() {
    if (this.dasDirection === 'right') {
      return;
    }
    this.dasDirection = 'right';
    this.dasElapsed = 0;
    this.arrElapsed = 0;
    this.tryMove(1, 0);
  }

  stopMoveRight() {
    if (this.dasDirection === 'right') {
      this.dasDirection = null;
    }
  }

  startSoftDrop() {
    this.softDropHeld = true;
  }

  stopSoftDrop() {
    this.softDropHeld = false;
  }

  handleKeyDown(keyEvent) {
    if (this.state.phase !== 'playing') {
      return;
    }
    const { code } = keyEvent;
    const repeat = this.pressedKeys.has(code);
    this.pressedKeys.add(code);

    if (code === KEY_LEFT) {
      this.startMoveLeft();
    } else if (code === KEY_RIGHT) {
      this.startMoveRight();
    } else if (code === KEY_DOWN) {
      this.startSoftDrop();
    } else if (repeat) {
      return;
    } else if (code === KEY_SPACE) {
      this.hardDrop();
    } else if (code === KEY_UP || code === KEY_X) {
      this.rotateCW();
    } else if (code === KEY_Z) {
      this.rotateCCW();
    } else if (code === KEY_C) {
      this.holdPiece();
    }
  }

  handleKeyUp(keyEvent) {
    const { code } = keyEvent;
    this.pressedKeys.delete(code);
    if (code === KEY_LEFT) {
      this.stopMoveLeft();
    } else if (code === KEY_RIGHT) {
      this.stopMoveRight();
    } else if (code === KEY_DOWN) {
      this.stopSoftDrop();
    }
  }

  updateAnimation(timestamp) {
    const last = this.lastFrame === null ? timestamp : this.lastFrame;
    const delta = timestamp - last;
    this.lastFrame = timestamp;

    if (this.state.phase === 'playing' && this.state.current) {
      if (this.state.mode === 'blitz' && Date.now() - this.gameStartTs >= BLITZ_DURATION_MS) {
        this.finishRun(true);
        return;
      }

      if (this.dasDirection) {
        this.dasElapsed += delta;
        if (this.dasElapsed >= DAS_MS) {
          this.arrElapsed += delta;
          while (this.arrElapsed >= ARR_MS) {
            this.arrElapsed -= ARR_MS;
            this.tryMove(this.dasDirection === 'left' ? -1 : 1, 0);
          }
        }
      }

      const interval = this.softDropHeld ? SOFT_DROP_MS : gravityMs(this.state.level);
      this.dropAccumulator += delta;
      while (this.dropAccumulator >= interval) {
        this.dropAccumulator -= interval;
        const { board, current } = this.state;
        if (current && !collides(board, current.matrix, current.x, current.y + 1)) {
          this.grounded = false;
          this.setState({ current: { ...current, y: current.y + 1 } });
        } else if (current) {
          this.grounded = true;
        }
      }

      if (this.grounded) {
        this.lockTimer -= delta;
        if (this.lockTimer <= 0) {
          this.lockCurrent();
        }
      }

      this.syncAccumulator += delta;
      if (this.syncAccumulator >= SYNC_MS) {
        this.syncAccumulator = 0;
        this.pushSync();
      }

      this.statusAccumulator += delta;
      if (this.statusAccumulator >= STATUS_UPDATE_MS) {
        this.statusAccumulator -= STATUS_UPDATE_MS;
        const elapsed = Date.now() - this.gameStartTs;
        const statusMs =
          this.state.mode === 'blitz' ? Math.max(0, BLITZ_DURATION_MS - elapsed) : elapsed;
        this.setState({ statusMs });
      }
    }

    this.animationId = window.requestAnimationFrame(this.updateAnimation);
  }

  render() {
    const {
      phase,
      board,
      current,
      queue,
      hold,
      score,
      lines,
      level,
      mode,
      statusMs,
      completed,
    } = this.state;
    const {
      highScore,
      blitzHighScore,
      sprintBestDs,
      garbageBestDs,
      tickets,
      isCabinet,
      onClaimTickets,
    } = this.props;

    const displayBoard = buildDisplayBoard(board, current);
    const ghostBoard = buildGhostBoard(board, current);

    let resultText = null;
    if (phase === 'gameover') {
      if (mode === 'blitz') {
        resultText = completed ? `Time's up — ${score} pts` : `Topped out — ${score} pts`;
      } else if (mode === 'sprint') {
        resultText = completed
          ? `Cleared 40 lines in ${formatTime(statusMs)}!`
          : `Topped out — ${lines}/${SPRINT_TARGET_LINES} lines`;
      } else if (mode === 'garbage') {
        resultText = completed
          ? `Garbage cleared in ${formatTime(statusMs)}!`
          : `Topped out — ${lines}/${GARBAGE_TARGET_LINES} lines`;
      } else {
        resultText = `Game Over — ${score} pts`;
      }
    }

    return (
      <Stack fill vertical>
        {phase === 'playing' && (
          <KeyListener onKeyDown={this.handleKeyDown} onKeyUp={this.handleKeyUp} />
        )}
        <Stack.Item>
          <Stack>
            <Stack.Item>
              <Section title="Board">
                <BoardGrid
                  board={displayBoard}
                  ghost={ghostBoard}
                  overlay={
                    phase !== 'playing' && (
                      <Stack vertical>
                        {resultText && (
                          <Stack.Item>
                            <Box
                              color={completed === false ? 'bad' : 'good'}
                              bold
                              mb={1}
                              textAlign="center"
                            >
                              {resultText}
                            </Box>
                          </Stack.Item>
                        )}
                        <Stack.Item>
                          <ModeSelect mode={mode} onSelect={this.selectMode} />
                        </Stack.Item>
                        <Stack.Item>
                          <Button
                            fluid
                            content="New Game"
                            color="blue"
                            onClick={this.startNewGame}
                          />
                        </Stack.Item>
                      </Stack>
                    )
                  }
                />
              </Section>
            </Stack.Item>
            <Stack.Item width="150px">
              <Stack vertical fill>
                <Stack.Item>
                  <Section title="Hold">{renderMiniPiece(hold)}</Section>
                </Stack.Item>
                <Stack.Item>
                  <Section title="Next">
                    <Stack vertical>
                      {queue.map((type, index) => (
                        <Stack.Item key={index}>{renderMiniPiece(type)}</Stack.Item>
                      ))}
                    </Stack>
                  </Section>
                </Stack.Item>
                <Stack.Item grow>
                  <Section title="Stats" fill>
                    <StatsBlock
                      mode={mode}
                      score={score}
                      lines={lines}
                      level={level}
                      statusMs={statusMs}
                      highScore={highScore}
                      blitzHighScore={blitzHighScore}
                      sprintBestDs={sprintBestDs}
                      garbageBestDs={garbageBestDs}
                      tickets={tickets}
                    />
                  </Section>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        </Stack.Item>
        <Stack.Item>
          <Section>
            <Stack>
              <Stack.Item>
                <Button
                  icon="arrow-left"
                  tooltip="Move left (←)"
                  onMouseDown={this.startMoveLeft}
                  onMouseUp={this.stopMoveLeft}
                  onMouseLeave={this.stopMoveLeft}
                  disabled={phase !== 'playing'}
                />
                <Button
                  icon="arrow-right"
                  tooltip="Move right (→)"
                  onMouseDown={this.startMoveRight}
                  onMouseUp={this.stopMoveRight}
                  onMouseLeave={this.stopMoveRight}
                  disabled={phase !== 'playing'}
                />
                <Button
                  icon="rotate-left"
                  tooltip="Rotate CCW (Z)"
                  onClick={this.rotateCCW}
                  disabled={phase !== 'playing'}
                />
                <Button
                  icon="rotate-right"
                  tooltip="Rotate CW (↑ / X)"
                  onClick={this.rotateCW}
                  disabled={phase !== 'playing'}
                />
                <Button
                  icon="arrow-down"
                  tooltip="Soft drop (↓)"
                  onMouseDown={this.startSoftDrop}
                  onMouseUp={this.stopSoftDrop}
                  onMouseLeave={this.stopSoftDrop}
                  disabled={phase !== 'playing'}
                />
                <Button
                  icon="angle-double-down"
                  tooltip="Hard drop (Space)"
                  onClick={this.hardDrop}
                  disabled={phase !== 'playing'}
                />
                <Button
                  icon="right-left"
                  tooltip="Hold (C)"
                  onClick={this.holdPiece}
                  disabled={phase !== 'playing' || !this.state.canHold}
                />
              </Stack.Item>
              <Stack.Item grow />
              <Stack.Item>
                <KeybindsHelpButton />
                <Button
                  content="New Game"
                  color="blue"
                  onClick={this.startNewGame}
                  disabled={phase === 'playing'}
                />
                {isCabinet && (
                  <Button
                    content="Claim Tickets"
                    color="green"
                    disabled={!tickets}
                    onClick={onClaimTickets}
                  />
                )}
              </Stack.Item>
            </Stack>
          </Section>
        </Stack.Item>
      </Stack>
    );
  }
}

// Read-only view for anyone who isn't the current player: renders whatever board snapshot
// the active player's client last pushed instead of running its own game loop.
const TetrisSpectator = (props) => {
  const {
    snapshot,
    gameStatus,
    lastScore,
    lastLines,
    highScore,
    blitzHighScore,
    sprintBestDs,
    garbageBestDs,
    tickets,
    isCabinet,
    onNewGame,
    onClaimTickets,
  } = props;

  const board = snapshot?.board || makeEmptyBoard();
  const hold = snapshot?.hold ?? null;
  const queue = snapshot?.queue || [];
  const score = snapshot?.score ?? lastScore ?? 0;
  const lines = snapshot?.lines ?? lastLines ?? 0;
  const level = snapshot?.level ?? 1;
  const mode = snapshot?.mode ?? 'marathon';
  const statusMs = snapshot?.statusMs ?? 0;
  const finished = gameStatus === TETRIS_GAMEOVER;
  const canTakeOver = gameStatus !== TETRIS_PLAYING;

  return (
    <Stack fill vertical>
      <Stack.Item>
        <Stack>
          <Stack.Item>
            <Section title="Board (Spectating)">
              <BoardGrid
                board={board}
                overlay={
                  (finished || !snapshot) && (
                    <>
                      {finished && (
                        <Box color="bad" bold mb={1}>
                          Game Over — {score} pts
                        </Box>
                      )}
                      {!snapshot && <Box color="label">Waiting for a game to start…</Box>}
                    </>
                  )
                }
              />
            </Section>
          </Stack.Item>
          <Stack.Item width="150px">
            <Stack vertical fill>
              <Stack.Item>
                <Section title="Hold">{renderMiniPiece(hold)}</Section>
              </Stack.Item>
              <Stack.Item>
                <Section title="Next">
                  <Stack vertical>
                    {queue.map((type, index) => (
                      <Stack.Item key={index}>{renderMiniPiece(type)}</Stack.Item>
                    ))}
                  </Stack>
                </Section>
              </Stack.Item>
              <Stack.Item grow>
                <Section title="Stats" fill>
                  <StatsBlock
                    mode={mode}
                    score={score}
                    lines={lines}
                    level={level}
                    statusMs={statusMs}
                    highScore={highScore}
                    blitzHighScore={blitzHighScore}
                    sprintBestDs={sprintBestDs}
                    garbageBestDs={garbageBestDs}
                    tickets={tickets}
                  />
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Stack.Item>
      <Stack.Item>
        <Section>
          <Stack>
            <Stack.Item color="label">
              Spectating — someone else has the controls.
            </Stack.Item>
            <Stack.Item grow />
            <Stack.Item>
              <KeybindsHelpButton />
              {canTakeOver && (
                <Button
                  content="Take Over"
                  color="blue"
                  tooltip="Claim the controls, then press New Game to start"
                  onClick={onNewGame}
                />
              )}
              {isCabinet && (
                <Button
                  content="Claim Tickets"
                  color="green"
                  disabled={!tickets}
                  onClick={onClaimTickets}
                />
              )}
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>
    </Stack>
  );
};

export const TetrisContent = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    high_score = 0,
    blitz_high_score = 0,
    sprint_best_ds = 0,
    garbage_best_ds = 0,
    tickets = 0,
    is_cabinet,
    is_player,
    game_status = TETRIS_IDLE,
    snapshot,
    last_score = 0,
    last_lines = 0,
  } = data;

  // Nobody's claimed the machine yet (fresh IDLE state) means anyone gets the interactive
  // idle/New Game screen; once a game is underway or just finished, only the player who
  // started it does, everyone else spectates their last synced snapshot.
  const showControls = is_player || game_status === TETRIS_IDLE;

  return showControls ? (
    <TetrisGame
      highScore={high_score}
      blitzHighScore={blitz_high_score}
      sprintBestDs={sprint_best_ds}
      garbageBestDs={garbage_best_ds}
      tickets={tickets}
      isCabinet={is_cabinet}
      onNewGame={() => act('PRG_new_game')}
      onGameOver={(score, lines, mode, completed) =>
        act('PRG_game_over', { score, lines, mode, completed })
      }
      onSync={(snap, sfx) => act('PRG_sync', { snapshot: snap, sfx })}
      onClaimTickets={() => act('PRG_tickets')}
    />
  ) : (
    <TetrisSpectator
      snapshot={snapshot}
      gameStatus={game_status}
      lastScore={last_score}
      lastLines={last_lines}
      highScore={high_score}
      blitzHighScore={blitz_high_score}
      sprintBestDs={sprint_best_ds}
      garbageBestDs={garbage_best_ds}
      tickets={tickets}
      isCabinet={is_cabinet}
      onNewGame={() => act('PRG_new_game')}
      onClaimTickets={() => act('PRG_tickets')}
    />
  );
};

export const Tetris = (props, context) => {
  return (
    <Window width={410} height={600}>
      <Window.Content>
        <TetrisContent />
      </Window.Content>
    </Window>
  );
};
