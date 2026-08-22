// THIS IS A META UI FILE
import { Component, memo, useEffect, useRef, useState } from 'react';
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
// Caps accumulator-loop ticks processed per frame. Without it, time banked against a slow
// interval (e.g. gravity) gets reinterpreted at a much faster one the instant it changes (e.g.
// soft drop), or piles up after a hitch, letting one frame slam the piece across the whole
// board like an instant drop.
const MAX_CATCHUP_TICKS = 4;
const LOCK_DELAY_MS = 500;
const MAX_LOCK_RESETS = 15;
// How often the player's client pushes a board snapshot for spectators. Matches
// config/comms.txt's TICKLAG (0.5s), since the server can't relay updates faster than one per
// world tick anyway.
const SYNC_MS = 250;

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

// I is a 4x4 box (spans its own width/height, no off-center drift). O is a plain 2x2 (rotation
// is always a no-op). The rest are 3x3 with the pivot cell at true center [1][1], so
// rotateMatrix spins them in place instead of visibly shifting the piece on every press.
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

// Fades a piece color for the ghost outline, so it reads as a preview rather than a second
// copy of the piece itself.
const GHOST_ALPHA = 0.55;
const withAlpha = (hex, alpha) => {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
};

// Standard SRS wall/floor kicks, one 5-test list per specific rotation transition ("0>1" =
// spawn rotating CW into R, etc.) rather than one shared list. A shared list lets whichever
// kick collides-free first win even if it's wrong for that spin, skipping a valid target for a
// nearer useless one; per-transition tables avoid that.
//
// Converted from the published SRS docs (+y = up) to this board's y-down convention by
// negating every source y.
const JLSTZ_KICKS = {
  '0>1': [[0, 0], [-1, 0], [-1, -1], [0, 2], [-1, 2]],
  '1>0': [[0, 0], [1, 0], [1, 1], [0, -2], [1, -2]],
  '1>2': [[0, 0], [1, 0], [1, 1], [0, -2], [1, -2]],
  '2>1': [[0, 0], [-1, 0], [-1, -1], [0, 2], [-1, 2]],
  '2>3': [[0, 0], [1, 0], [1, -1], [0, 2], [1, 2]],
  '3>2': [[0, 0], [-1, 0], [-1, 1], [0, -2], [-1, -2]],
  '3>0': [[0, 0], [-1, 0], [-1, 1], [0, -2], [-1, -2]],
  '0>3': [[0, 0], [1, 0], [1, -1], [0, 2], [1, 2]],
};

const I_KICKS = {
  '0>1': [[0, 0], [-2, 0], [1, 0], [-2, 1], [1, -2]],
  '1>0': [[0, 0], [2, 0], [-1, 0], [2, -1], [-1, 2]],
  '1>2': [[0, 0], [-1, 0], [2, 0], [-1, -2], [2, 1]],
  '2>1': [[0, 0], [1, 0], [-2, 0], [1, 2], [-2, -1]],
  '2>3': [[0, 0], [2, 0], [-1, 0], [2, -1], [-1, 2]],
  '3>2': [[0, 0], [-2, 0], [1, 0], [-2, 1], [1, -2]],
  '3>0': [[0, 0], [1, 0], [-2, 0], [1, 2], [-2, -1]],
  '0>3': [[0, 0], [-1, 0], [2, 0], [-1, -2], [2, 1]],
};

// O never visually changes when it rotates, so there's nothing to kick.
const O_KICKS = {
  '0>1': [[0, 0]], '1>0': [[0, 0]], '1>2': [[0, 0]], '2>1': [[0, 0]],
  '2>3': [[0, 0]], '3>2': [[0, 0]], '3>0': [[0, 0]], '0>3': [[0, 0]],
};

const KICK_TABLES = { T: JLSTZ_KICKS, S: JLSTZ_KICKS, Z: JLSTZ_KICKS, J: JLSTZ_KICKS, L: JLSTZ_KICKS, I: I_KICKS, O: O_KICKS };

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

// Where the piece would land on a hard drop, for the ghost outline (null once already resting
// there). A sparse {x,y,type} list rather than a full board, since allocating a whole empty
// array just to mark ~4 cells on every render was avoidable GC pressure.
const buildGhostCells = (board, current) => {
  if (!current) {
    return null;
  }
  const dist = dropDistance(board, current.matrix, current.x, current.y);
  if (dist === 0) {
    return null;
  }
  const cells = [];
  const ghostY = current.y + dist;
  for (let y = 0; y < current.matrix.length; y++) {
    for (let x = 0; x < current.matrix[y].length; x++) {
      if (!current.matrix[y][x]) {
        continue;
      }
      const by = ghostY + y;
      const bx = current.x + x;
      if (by >= 0 && by < BOARD_H && bx >= 0 && bx < BOARD_W) {
        cells.push({ x: bx, y: by, type: current.type });
      }
    }
  }
  return cells;
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

// Garbage Race's objective is clearing the pre-filled garbage specifically, not any 13 lines,
// so a row built entirely from the player's own pieces shouldn't count. Call on the pre-clear
// (merged) board, since clearLines only reports how many rows were removed, not what was in
// them.
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

// The standard "3-corner rule" for T-spins, generalized to every 3x3-boxed piece: counts
// occupied bounding-box corners (board edge/floor or a filled cell). 3+ occupied means the
// piece is wedged in tight enough to count as a spin.
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
  // 0=spawn, 1=CW (R), 2=180, 3=CCW (L). Looks up the right transition in the per-transition
  // kick tables, see rotate().
  rotationIndex: 0,
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

// Packs a board into a flat 200-char string instead of a JSON array, for the snapshot sent
// over act()/Topic(). The array form sits right around tgui's 2048-char chunking threshold,
// turning most syncs into a slower multi-message exchange. '#' stands in for the garbage
// pseudo-type since it isn't one character.
const encodeCell = (cell) => (cell ? (cell === 'GARBAGE' ? '#' : cell) : '.');
const decodeCell = (ch) => (ch === '.' ? null : ch === '#' ? 'GARBAGE' : ch);

const encodeBoard = (board) => board.map((row) => row.map(encodeCell).join('')).join('');

const decodeBoard = (encoded) => {
  const rows = [];
  for (let y = 0; y < BOARD_H; y++) {
    rows.push(encoded.slice(y * BOARD_W, (y + 1) * BOARD_W).split('').map(decodeCell));
  }
  return rows;
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

// How long a just-cleared glow keeps its (fading-out) box-shadow styling before dropping back
// to a plain cell. Must be >= the CSS transition duration below so the fade actually finishes.
const GLOW_FADE_HOLD_MS = 220;

// Whether the falling piece occupies board cell (x,y), for merging it into the display inline
// during BoardGrid's per-cell loop instead of pre-allocating a whole merged board on every
// render. Spectators still use buildDisplayBoard, since they have no `current` piece and
// update far less often.
const pieceCellAt = (current, x, y) => {
  if (!current) {
    return null;
  }
  const ry = y - current.y;
  const rx = x - current.x;
  if (ry < 0 || ry >= current.matrix.length || rx < 0 || rx >= current.matrix[ry].length) {
    return null;
  }
  return current.matrix[ry][rx] ? current.type : null;
};

// Cheap content equality for the small (0-4 cell) ghost/glow lists, which are rebuilt fresh on
// every render regardless of whether anything actually changed.
const cellListsEqual = (a, b) => {
  if (a === b) {
    return true;
  }
  if (!a?.length && !b?.length) {
    return true;
  }
  if (a?.length !== b?.length) {
    return false;
  }
  return a.every((cell, i) => cell.x === b[i].x && cell.y === b[i].y && cell.type === b[i].type);
};

// BoardGrid renders 200 cells on every gravity/DAS tick, so re-rendering on every parent
// setState (even unrelated ones, like the status timer) was real reconciliation cost paid many
// times a second. `current.matrix` only gets a new reference on an actual rotation, so
// comparing it by reference is equivalent to a full value check.
const boardGridPropsEqual = (prev, next) => {
  if (prev.board !== next.board) {
    return false;
  }
  if (prev.current !== next.current) {
    const pc = prev.current;
    const nc = next.current;
    if (!pc || !nc) {
      return false;
    }
    if (pc.type !== nc.type || pc.x !== nc.x || pc.y !== nc.y || pc.matrix !== nc.matrix) {
      return false;
    }
  }
  if (!cellListsEqual(prev.ghost, next.ghost)) {
    return false;
  }
  if (!cellListsEqual(prev.glow, next.glow)) {
    return false;
  }
  if (prev.topBanner !== next.topBanner) {
    return false;
  }
  return Boolean(prev.overlay) === Boolean(next.overlay) && prev.overlay === next.overlay;
};

const BoardGrid = memo(({ board, current, ghost, overlay, topBanner, glow }) => {
  // Only actively-glowing (or just-faded) cells carry the box-shadow/transition styling.
  // Applying that to all 200 cells on every render was a real, measurable cost for no visible
  // benefit on the other 190+.
  const prevGlowRef = useRef(null);
  const [fadingCells, setFadingCells] = useState(null);

  useEffect(() => {
    if (glow?.length) {
      prevGlowRef.current = glow;
      setFadingCells(null);
      return undefined;
    }
    if (prevGlowRef.current) {
      const cells = prevGlowRef.current;
      prevGlowRef.current = null;
      setFadingCells(cells);
      const timer = window.setTimeout(() => setFadingCells(null), GLOW_FADE_HOLD_MS);
      return () => window.clearTimeout(timer);
    }
    return undefined;
  }, [glow]);

  const glowSet = glow?.length ? new Set(glow.map(({ x, y }) => `${x}-${y}`)) : null;
  const fadingSet = fadingCells?.length
    ? new Set(fadingCells.map(({ x, y }) => `${x}-${y}`))
    : null;
  const ghostMap = ghost?.length ? new Map(ghost.map((c) => [`${c.x}-${c.y}`, c.type])) : null;

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
          const mergedCell = current ? pieceCellAt(current, x, y) || cell : cell;
          const key = `${x}-${y}`;
          const ghostType = !mergedCell && ghostMap?.get(key);
          const isGlowing = glowSet?.has(key);
          const needsShadowStyling = isGlowing || fadingSet?.has(key);
          return (
            <Box
              key={key}
              style={{
                'background-color': mergedCell ? COLORS[mergedCell] : 'rgba(255,255,255,0.03)',
                'box-sizing': 'border-box',
                border: ghostType ? `2px solid ${withAlpha(COLORS[ghostType], GHOST_ALPHA)}` : 'none',
                ...(needsShadowStyling && {
                  'box-shadow': isGlowing
                    ? '0 0 6px 2px #fff, inset 0 0 6px 2px #fff'
                    : '0 0 6px 2px transparent, inset 0 0 6px 2px transparent',
                  // Only box-shadow transitions; background-color/border update instantly so
                  // piece/ghost movement never looks like it's lagging behind.
                  transition: 'box-shadow 180ms ease-out',
                }),
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
}, boardGridPropsEqual);

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
    this.pendingCommit = null;
    this.clearFlashElapsed = 0;

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
      board: encodeBoard(buildDisplayBoard(board, current)),
      ghost: buildGhostCells(board, current),
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
    // If the last game ended while a direction/soft-drop key was still held, no fresh keydown
    // fires here to re-arm these, so the new piece could inherit stale DAS/ARR state and start
    // sliding on its first frame. pressedKeys is left alone, since clearing it would misread the
    // next OS auto-repeat event for that key as a fresh press.
    this.dasDirection = null;
    this.dasElapsed = 0;
    this.arrElapsed = 0;
    this.softDropHeld = false;
    this.lastRotated = false;
    this.bannerToken = null;
    this.glowToken = null;
    this.pendingCommit = null;
    this.clearFlashElapsed = 0;

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
  // hitting the mode's goal / blitz's clock running out (completed = true).
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

  // `pieceOverride`, when given, is locked instead of re-reading this.state.current;
  // `bonusScore` folds into the same setState call instead of being applied separately, see
  // hardDrop().
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

    // Garbage Race's progress is tracked separately from totalLines (which still governs
    // scoring/level uniformly), since only garbage-containing rows count. See countGarbageRows().
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
      // Piece cells that survived the clear, remapped to their post-clear row (a spin that also
      // clears lines shifts rows above it down), so the glow lands on the right cells.
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
      // Flash the full rows in place (still part of `merged`) before clearing them, so the glow
      // lands on what the player is watching disappear, not nothing.
      this.showBanner(label);
      const flashCells = [];
      for (let y = 0; y < BOARD_H; y++) {
        if (merged[y].every((cell) => cell)) {
          for (let x = 0; x < BOARD_W; x++) {
            flashCells.push({ x, y });
          }
        }
      }
      // Cleared exactly when commit() removes these rows; their coordinates mean nothing once
      // the board shifts, so a lingering glow past that point would light up unrelated cells.
      this.showGlow(flashCells, CLEAR_FLASH_MS);
      this.setState({ board: merged, current: null });
      this.clearFlashElapsed = 0;
      this.pendingCommit = commit;
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
    // Functional form, applying (dx, dy) as a relative offset onto prevState.current rather
    // than the absolute nx/ny above, so a same-batch gravity/DAS update composes instead of
    // getting overwritten, same reasoning as rotate().
    this.setState((prevState) => ({
      current: prevState.current
        ? { ...prevState.current, x: prevState.current.x + dx, y: prevState.current.y + dy }
        : prevState.current,
    }));
    this.updateGroundedState(board, current.matrix, nx, ny);
    this.lastRotated = false;
    return true;
  }

  // A move/rotate can slide the piece off its ledge into open space below, so gravity must
  // resume immediately instead of keeping the stale "grounded" flag, or the lock timer keeps
  // counting down and the piece locks floating in mid-air.
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
    const fromState = current.rotationIndex;
    const toState = (fromState + dir + 4) % 4;
    const rotated = rotateMatrix(current.matrix, dir);
    const table = KICK_TABLES[current.type] || JLSTZ_KICKS;
    const kicks = table[`${fromState}>${toState}`] || [[0, 0]];
    for (const [dx, dy] of kicks) {
      const nx = current.x + dx;
      const ny = current.y + dy;
      if (!collides(board, rotated, nx, ny)) {
        // Functional form, applying the kick as a relative offset onto prevState.current
        // rather than the absolute nx/ny above, so this composes with a same-batch gravity/DAS
        // update, see tryMove().
        this.setState((prevState) => ({
          current: prevState.current
            ? {
                ...prevState.current,
                matrix: rotated,
                x: prevState.current.x + dx,
                y: prevState.current.y + dy,
                rotationIndex: toState,
              }
            : prevState.current,
        }));
        this.updateGroundedState(board, rotated, nx, ny);
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

  // Locks synchronously off a locally-computed piece instead of setState-and-callback. A
  // keydown landing in the gap between them could change this.state.current.x to something the
  // drop distance below was never checked against, locking into an unvalidated column. Reading
  // state once and finishing synchronously closes that window.
  hardDrop() {
    const { board, current } = this.state;
    if (!current) {
      return;
    }
    const dist = dropDistance(board, current.matrix, current.x, current.y);
    // If the piece had further to fall, wherever it lands has nothing to do with where it was
    // last rotated (those corners were never validated for this landing), so this no longer
    // counts as a rotation for spin purposes. Only dist === 0 (already resting where it
    // rotated) keeps it.
    if (dist > 0) {
      this.lastRotated = false;
    }
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
    // dropAccumulator's banked time was accrued against gravity's slow interval; reinterpreting
    // it at SOFT_DROP_MS the instant the rate changes would let a tap inherit stale gravity
    // credit as extra rows. Only reset on the actual off-to-on edge, since held keys resend
    // keydown at the OS repeat rate and resetting every time would never let it reach
    // SOFT_DROP_MS.
    if (!this.softDropHeld) {
      this.dropAccumulator = 0;
    }
    this.softDropHeld = true;
  }

  stopSoftDrop() {
    if (this.softDropHeld) {
      this.dropAccumulator = 0;
    }
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

    // Outside the phase/current gate below since `current` is null during the flash window.
    // Ticks off real frames, not wall-clock time, see lockCurrent()'s isBigClear branch.
    if (this.pendingCommit) {
      this.clearFlashElapsed += delta;
      if (this.clearFlashElapsed >= CLEAR_FLASH_MS) {
        const commit = this.pendingCommit;
        this.pendingCommit = null;
        commit();
      }
    }

    if (this.state.phase === 'playing' && this.state.current) {
      if (this.state.mode === 'blitz' && Date.now() - this.gameStartTs >= BLITZ_DURATION_MS) {
        this.finishRun(true);
        return;
      }

      // Both blocks below can move the same piece in one call (e.g. DAS sliding it the same
      // frame gravity drops it), so they share one local `current` instead of each
      // independently re-reading `this.state.current`, which would let gravity's collision
      // check run against the pre-DAS column.
      const { board } = this.state;
      let current = this.state.current;
      let moved = false;

      if (this.dasDirection) {
        this.dasElapsed += delta;
        if (this.dasElapsed >= DAS_MS) {
          this.arrElapsed = Math.min(this.arrElapsed + delta, ARR_MS * MAX_CATCHUP_TICKS);
          const dx = this.dasDirection === 'left' ? -1 : 1;
          let dasMoved = false;
          while (current && this.arrElapsed >= ARR_MS) {
            this.arrElapsed -= ARR_MS;
            const nx = current.x + dx;
            if (!collides(board, current.matrix, nx, current.y)) {
              current = { ...current, x: nx };
              moved = true;
              dasMoved = true;
            }
          }
          if (dasMoved) {
            this.updateGroundedState(board, current.matrix, current.x, current.y);
            this.lastRotated = false;
          }
        }
      }

      const interval = this.softDropHeld ? SOFT_DROP_MS : gravityMs(this.state.level);
      this.dropAccumulator = Math.min(this.dropAccumulator + delta, interval * MAX_CATCHUP_TICKS);
      while (current && this.dropAccumulator >= interval) {
        this.dropAccumulator -= interval;
        if (!collides(board, current.matrix, current.x, current.y + 1)) {
          current = { ...current, y: current.y + 1 };
          moved = true;
          this.grounded = false;
          this.lastRotated = false;
        } else {
          this.grounded = true;
        }
      }

      if (moved) {
        // Functional form: a keyboard move from tryMove()/rotate() can land in the same batch,
        // so this composes onto `prevState.current` instead of replacing it, same reasoning as
        // tryMove().
        const finalCurrent = current;
        this.setState((prevState) => ({
          current: prevState.current
            ? { ...prevState.current, x: finalCurrent.x, y: finalCurrent.y }
            : prevState.current,
        }));
      }

      if (this.grounded) {
        this.lockTimer -= delta;
        if (this.lockTimer <= 0) {
          // Passes the position already computed above, instead of letting lockCurrent() fall
          // back to this.state.current, which can be one frame stale, same reasoning as
          // hardDrop()'s pieceOverride.
          this.lockCurrent(current);
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

    // No pre-merged board here: BoardGrid merges the falling piece into `board` inline per
    // cell, since building a whole separate 200-cell array on every gravity/DAS tick was
    // avoidable allocation pressure.
    const ghostCells = buildGhostCells(board, current);

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
                  board={board}
                  current={current}
                  ghost={ghostCells}
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
    isAbandoned,
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

  const board = snapshot?.board ? decodeBoard(snapshot.board) : makeEmptyBoard();
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
  const canTakeOver = gameStatus !== TETRIS_PLAYING || isAbandoned;

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
              {isAbandoned
                ? 'Spectating — the player left without finishing, this game looks abandoned.'
                : 'Spectating — someone else has the controls.'}
            </Stack.Item>
            <Stack.Item grow />
            <Stack.Item>
              {canTakeOver && (
                <Button
                  content={isAbandoned ? 'Reclaim' : 'Take Over'}
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
    is_abandoned,
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
      isAbandoned={is_abandoned}
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
