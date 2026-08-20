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

// `survivorRows[newY] = oldY` for every row that made it through the clear, so a caller that
// cared about specific cells at their old positions (the spin glow, below) can find out where
// they ended up rather than just knowing how many rows shifted.
const clearLines = (board) => {
  const keptOldIndices = [];
  const remaining = board.filter((row, oldY) => {
    const keep = row.some((cell) => !cell);
    if (keep) {
      keptOldIndices.push(oldY);
    }
    return keep;
  });
  const cleared = BOARD_H - remaining.length;
  while (remaining.length < BOARD_H) {
    remaining.unshift(new Array(BOARD_W).fill(null));
  }
  const survivorRows = new Map();
  keptOldIndices.forEach((oldY, i) => {
    survivorRows.set(oldY, cleared + i);
  });
  return { board: remaining, cleared, survivorRows };
};

// Garbage Race's objective is clearing the pre-filled garbage specifically, not just any 13
// lines. A row built entirely from the player's own pieces above the stack, with no garbage
// cell in it at all, shouldn't count. Call on the pre-clear (merged) board, since clearLines
// only returns how many rows were removed, not what was in them.
const countGarbageRows = (board) => {
  let count = 0;
  for (const row of board) {
    if (row.every((cell) => cell) && row.includes('GARBAGE')) {
      count++;
    }
  }
  return count;
};

const LINE_SCORES = [0, 100, 300, 500, 800];

const gravityMs = (level) => Math.max(120, 900 - (level - 1) * 70);

// Only the 3x3-boxed pieces (T/S/Z/J/L) get spin detection. O can't meaningfully spin, since a
// rotation is always a no-op on it, and I's 4x4 box doesn't fit the same corner geometry.
const SPIN_NAMES = { T: 'T-Spin', S: 'S-Spin', Z: 'Z-Spin', J: 'J-Spin', L: 'L-Spin' };
const SPIN_CLEAR_SUFFIX = ['', ' Single', ' Double', ' Triple', ' Quad'];
const SPIN_NO_CLEAR_BONUS = 100;
const SPIN_CLEAR_MULTIPLIER = 2;
const SPIN_BANNER_MS = 1600;
const SPIN_GLOW_MS = 700;

// A non-spin clear of this many lines or more (Triple, Tetris) gets the same banner/glow/sfx
// treatment as a spin, plus a brief flash of the full rows before they're actually removed.
const BIG_CLEAR_THRESHOLD = 3;
const CLEAR_FLASH_MS = 500;
const CLEAR_NAMES = ['', 'Single', 'Double', 'Triple', 'Tetris'];

// The standard "3-corner rule" used to detect T-spins, generalized here to every 3x3-boxed
// piece: counts how many of the piece's bounding-box corners are occupied, by the board
// edge/floor or an actual filled cell. 3+ occupied corners means the piece is wedged in tight
// enough (on a spot it could only have reached by rotating into it) to count as a spin.
const countOccupiedCorners = (board, x, y) => {
  const corners = [
    [x, y],
    [x + 2, y],
    [x, y + 2],
    [x + 2, y + 2],
  ];
  let count = 0;
  for (const [cx, cy] of corners) {
    if (cx < 0 || cx >= BOARD_W || cy >= BOARD_H) {
      count++;
      continue;
    }
    if (cy < 0) {
      continue;
    }
    if (board[cy][cx]) {
      count++;
    }
  }
  return count;
};

const formatTime = (ms) => {
  const totalSeconds = Math.max(0, ms) / 1000;
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, '0')}:${seconds.toFixed(1).padStart(4, '0')}`;
};

// Server-tracked bests (sprint_best_ds/garbage_best_ds) are in deciseconds, not ms.
const formatDs = (ds) => formatTime(ds * 100);

// The board Section header is narrow (~230px), so a long RP name would wrap to a second line
// and break the layout without this.
const MAX_PLAYER_NAME_LEN = 14;
const truncateName = (name) =>
  name && name.length > MAX_PLAYER_NAME_LEN
    ? `${name.slice(0, MAX_PLAYER_NAME_LEN - 1)}…`
    : name;

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

const BoardGrid = ({ board, ghost, overlay, topBanner, glow }) => {
  const glowSet = glow?.length ? new Set(glow.map(({ x, y }) => `${x}-${y}`)) : null;
  return (
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
          const isGlowing = glowSet?.has(`${x}-${y}`);
          return (
            <Box
              key={`${x}-${y}`}
              style={{
                'background-color': cell ? COLORS[cell] : 'rgba(255,255,255,0.03)',
                'box-sizing': 'border-box',
                border: ghostType ? `2px solid ${COLORS[ghostType]}` : 'none',
                'box-shadow': isGlowing
                  ? '0 0 6px 2px #fff, inset 0 0 6px 2px #fff'
                  : '0 0 6px 2px transparent, inset 0 0 6px 2px transparent',
                // Only box-shadow transitions. background-color/border update instantly since
                // those change every frame during normal play, and a piece moving or the ghost
                // outline shifting should never look like it's lagging behind.
                transition: 'box-shadow 180ms ease-out',
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
    {topBanner && (
      <Box
        style={{
          position: 'absolute',
          top: '4px',
          left: 0,
          right: 0,
          display: 'flex',
          'justify-content': 'center',
          'pointer-events': 'none',
        }}
      >
        <Box
          bold
          style={{
            'background-color': 'rgba(0,0,0,0.8)',
            color: '#7cfc90',
            padding: '3px 10px',
            'border-radius': '4px',
            'font-size': '12px',
            'white-space': 'nowrap',
          }}
        >
          {topBanner}
        </Box>
      </Box>
    )}
    </Box>
  );
};

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
// Appends " (holder)" to a best-record line when someone's actually set one.
const holderSuffix = (holder) => (holder ? ` (${holder})` : '');

const StatsBlock = ({
  mode,
  score,
  lines,
  garbageCleared,
  level,
  statusMs,
  highScore,
  highScoreHolder,
  blitzHighScore,
  blitzHighScoreHolder,
  sprintBestDs,
  sprintBestHolder,
  garbageBestDs,
  garbageBestHolder,
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
          {holderSuffix(blitzHighScoreHolder)}
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
          <b>Best Time:</b>{' '}
          {sprintBestDs ? `${formatDs(sprintBestDs)}${holderSuffix(sprintBestHolder)}` : '--:--'}
        </Box>
      </>
    )}
    {mode === 'garbage' && (
      <>
        <Box>
          <b>Time:</b> {formatTime(statusMs)}
        </Box>
        <Box>
          <b>Garbage:</b> {garbageCleared}/{GARBAGE_TARGET_LINES}
        </Box>
        <Box>
          <b>Best Time:</b>{' '}
          {garbageBestDs
            ? `${formatDs(garbageBestDs)}${holderSuffix(garbageBestHolder)}`
            : '--:--'}
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
          {holderSuffix(highScoreHolder)}
        </Box>
      </>
    )}
    <Box>
      <b>Speed:</b> {gravityMs(level)}ms/row
    </Box>
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
    // Whether the last successful thing done to the current piece was a rotation (rather than
    // a slide or a fall), for spin detection - see lockCurrent().
    this.lastRotated = false;
    this.bannerToken = null;
    this.glowToken = null;

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
    const {
      board,
      current,
      hold,
      queue,
      score,
      lines,
      garbageCleared,
      level,
      mode,
      statusMs,
      banner,
      glow,
    } = this.state;
    return {
      board: buildDisplayBoard(board, current),
      ghost: buildGhostBoard(board, current),
      hold,
      queue,
      score,
      lines,
      garbageCleared,
      level,
      mode,
      statusMs,
      banner,
      glow,
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
      garbageCleared: 0,
      level: 1,
      statusMs: 0,
      completed: false,
      banner: null,
      glow: null,
    };
  }

  // Shows a transient "T-Spin Double! +1200"-style banner pinned to the top of the board.
  // Token-guarded so an older banner's timeout can't clear a newer one that landed within the
  // same window.
  showBanner(text) {
    const token = {};
    this.bannerToken = token;
    this.setState({ banner: text });
    window.setTimeout(() => {
      if (this.bannerToken === token) {
        this.setState({ banner: null });
      }
    }, SPIN_BANNER_MS);
  }

  // Highlights the given cells with a brief glow (a spin's own surviving cells, or the full
  // rows of a big non-spin clear while they're still visible). Same token-guard idea as the
  // banner.
  showGlow(cells, duration = SPIN_GLOW_MS) {
    const token = {};
    this.glowToken = token;
    this.setState({ glow: cells });
    window.setTimeout(() => {
      if (this.glowToken === token) {
        this.setState({ glow: null });
      }
    }, duration);
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
    this.lastRotated = false;
    this.bannerToken = null;
    this.glowToken = null;

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
        garbageCleared: 0,
        level: 1,
        statusMs: mode === 'blitz' ? BLITZ_DURATION_MS : 0,
        completed: false,
        banner: null,
        glow: null,
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
      this.lastRotated = false;
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

    // Spin eligibility: a 3x3-boxed piece, the last thing done to it was a rotation (not a
    // slide or a fall), and it's wedged in on 3+ of its bounding box's 4 corners.
    const spinName = current.matrix.length === 3 ? SPIN_NAMES[current.type] : undefined;
    const isSpin =
      !!spinName && this.lastRotated && countOccupiedCorners(board, current.x, current.y) >= 3;

    const merged = mergePiece(board, current.matrix, current.x, current.y, current.type);
    const { board: cleared, cleared: clearedCount, survivorRows } = clearLines(merged);
    const isBigClear = !isSpin && clearedCount >= BIG_CLEAR_THRESHOLD;

    let lineScoreGain;
    let label = null;
    if (isSpin) {
      lineScoreGain =
        clearedCount > 0
          ? LINE_SCORES[clearedCount] * level * SPIN_CLEAR_MULTIPLIER
          : SPIN_NO_CLEAR_BONUS * level;
      label = `${spinName}${SPIN_CLEAR_SUFFIX[clearedCount]}! +${lineScoreGain}`;
    } else {
      lineScoreGain = LINE_SCORES[clearedCount] * level;
      if (isBigClear) {
        label = `${CLEAR_NAMES[clearedCount]}! +${lineScoreGain}`;
      }
    }
    const scoreGain = lineScoreGain + bonusScore;

    const totalLines = this.state.lines + clearedCount;
    const newLevel = Math.floor(totalLines / 10) + 1;
    const sfx = isSpin
      ? 'spin'
      : clearedCount >= 4
        ? 'tetris'
        : clearedCount > 0
          ? 'clear'
          : 'lock';

    // Garbage Race's own progress is tracked separately from totalLines (which still governs
    // scoring/level for every mode uniformly), since only rows that actually contained garbage
    // should count toward its objective. See countGarbageRows().
    const totalGarbageCleared =
      mode === 'garbage' ? this.state.garbageCleared + countGarbageRows(merged) : 0;

    const objectiveComplete =
      mode === 'sprint'
        ? totalLines >= SPRINT_TARGET_LINES
        : mode === 'garbage'
          ? totalGarbageCleared >= GARBAGE_TARGET_LINES
          : false;

    const commit = () => {
      this.setState(
        {
          board: cleared,
          score: this.state.score + scoreGain,
          lines: totalLines,
          garbageCleared: totalGarbageCleared,
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
    };

    if (isSpin) {
      this.showBanner(label);
      // Any of the piece's own cells that survived the clear, remapped to their post-clear row
      // (a spin that also clears lines shifts rows above the clear down), so the glow lands on
      // the right cells instead of wherever they used to be.
      const glowCells = [];
      for (let py = 0; py < current.matrix.length; py++) {
        for (let px = 0; px < current.matrix[py].length; px++) {
          if (!current.matrix[py][px]) {
            continue;
          }
          const oldY = current.y + py;
          const newY = survivorRows.get(oldY);
          if (newY !== undefined) {
            glowCells.push({ x: current.x + px, y: newY });
          }
        }
      }
      this.showGlow(glowCells);
      commit();
      return;
    }

    if (isBigClear) {
      // Flash the full rows in place (still part of `merged`, not yet removed) before actually
      // clearing them, so the glow lands on the rows the player is watching disappear instead
      // of nothing (they're gone from `cleared` already).
      this.showBanner(label);
      const flashCells = [];
      for (let y = 0; y < BOARD_H; y++) {
        if (merged[y].every((cell) => cell)) {
          for (let x = 0; x < BOARD_W; x++) {
            flashCells.push({ x, y });
          }
        }
      }
      // Cleared exactly when commit() actually removes these rows, not after. Their
      // coordinates stop meaning anything once the board shifts, so any lingering glow past
      // that point would light up whatever unrelated cells happen to share those positions now.
      this.showGlow(flashCells, CLEAR_FLASH_MS);
      this.setState({ board: merged, current: null });
      window.setTimeout(commit, CLEAR_FLASH_MS);
      return;
    }

    commit();
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
    this.lastRotated = false;
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
        this.lastRotated = true;
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
    this.lastRotated = false;
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
          this.lastRotated = false;
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
      garbageCleared,
      level,
      mode,
      statusMs,
      completed,
      banner,
      glow,
    } = this.state;
    const {
      highScore,
      highScoreHolder,
      blitzHighScore,
      blitzHighScoreHolder,
      sprintBestDs,
      sprintBestHolder,
      garbageBestDs,
      garbageBestHolder,
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
          : `Topped out — ${garbageCleared}/${GARBAGE_TARGET_LINES} garbage lines`;
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
                  topBanner={banner}
                  glow={glow}
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
                      garbageCleared={garbageCleared}
                      level={level}
                      statusMs={statusMs}
                      highScore={highScore}
                      highScoreHolder={highScoreHolder}
                      blitzHighScore={blitzHighScore}
                      blitzHighScoreHolder={blitzHighScoreHolder}
                      sprintBestDs={sprintBestDs}
                      sprintBestHolder={sprintBestHolder}
                      garbageBestDs={garbageBestDs}
                      garbageBestHolder={garbageBestHolder}
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
    playerName,
    highScore,
    highScoreHolder,
    blitzHighScore,
    blitzHighScoreHolder,
    sprintBestDs,
    sprintBestHolder,
    garbageBestDs,
    garbageBestHolder,
    tickets,
    isCabinet,
    onNewGame,
    onClaimTickets,
  } = props;

  const board = snapshot?.board || makeEmptyBoard();
  const ghost = snapshot?.ghost ?? null;
  const banner = snapshot?.banner ?? null;
  const glow = snapshot?.glow ?? null;
  const hold = snapshot?.hold ?? null;
  const queue = snapshot?.queue || [];
  const score = snapshot?.score ?? lastScore ?? 0;
  const lines = snapshot?.lines ?? lastLines ?? 0;
  const garbageCleared = snapshot?.garbageCleared ?? 0;
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
            <Section
              title={playerName ? `Spectating ${truncateName(playerName)}` : 'Spectating'}
            >
              <BoardGrid
                board={board}
                ghost={ghost}
                topBanner={banner}
                glow={glow}
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
                    garbageCleared={garbageCleared}
                    level={level}
                    statusMs={statusMs}
                    highScore={highScore}
                    highScoreHolder={highScoreHolder}
                    blitzHighScore={blitzHighScore}
                    blitzHighScoreHolder={blitzHighScoreHolder}
                    sprintBestDs={sprintBestDs}
                    sprintBestHolder={sprintBestHolder}
                    garbageBestDs={garbageBestDs}
                    garbageBestHolder={garbageBestHolder}
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
    high_score_holder,
    blitz_high_score = 0,
    blitz_high_score_holder,
    sprint_best_ds = 0,
    sprint_best_holder,
    garbage_best_ds = 0,
    garbage_best_holder,
    tickets = 0,
    is_cabinet,
    is_player,
    game_status = TETRIS_IDLE,
    snapshot,
    last_score = 0,
    last_lines = 0,
    player_name,
  } = data;

  // Nobody's claimed the machine yet (fresh IDLE state) means anyone gets the interactive
  // idle/New Game screen; once a game is underway or just finished, only the player who
  // started it does, everyone else spectates their last synced snapshot.
  const showControls = is_player || game_status === TETRIS_IDLE;

  return showControls ? (
    <TetrisGame
      highScore={high_score}
      highScoreHolder={high_score_holder}
      blitzHighScore={blitz_high_score}
      blitzHighScoreHolder={blitz_high_score_holder}
      sprintBestDs={sprint_best_ds}
      sprintBestHolder={sprint_best_holder}
      garbageBestDs={garbage_best_ds}
      garbageBestHolder={garbage_best_holder}
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
      playerName={player_name}
      highScore={high_score}
      highScoreHolder={high_score_holder}
      blitzHighScore={blitz_high_score}
      blitzHighScoreHolder={blitz_high_score_holder}
      sprintBestDs={sprint_best_ds}
      sprintBestHolder={sprint_best_holder}
      garbageBestDs={garbage_best_ds}
      garbageBestHolder={garbage_best_holder}
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
