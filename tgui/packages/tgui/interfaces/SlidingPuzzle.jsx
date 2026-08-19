// THIS IS A META UI FILE
import { Box, Button, NumberInput, Section, Stack } from 'tgui-core/components';
import { clamp } from 'tgui-core/math';

import { useBackend } from '../backend';
import { Window } from '../layouts';

// Client-side render size of each board tile. The server always sends
// 48x48 tile images, this is just how big we draw them.
const TILE_PX = 48;
// Gap between tiles in the CSS grid (see the inline-grid style below).
const GRID_GAP = 2;
// Fixed overhead measured off the real rendered window: window margins,
// board section padding, and (height only) the title bar, header/footer
// sections, and gaps between them.
const WINDOW_CHROME_W = 29;
const WINDOW_CHROME_H = 236;
const MIN_WIDTH = 420;
const MAX_WIDTH = 700;
const MIN_HEIGHT = 385;
const MAX_HEIGHT = 755;

// Photo names cap at 32 chars, painting titles at MAX_NAME_LEN (42) server-side, either of which
// can wrap the single-line header/button rows at the window's minimum width. Truncate defensively
// instead of trusting font-metric math again.
const MAX_LABEL_LEN = 24;
const truncateLabel = (label) =>
  label && label.length > MAX_LABEL_LEN
    ? `${label.slice(0, MAX_LABEL_LEN - 1)}…`
    : label;

export const SlidingPuzzle = (props, context) => {
  const { data } = useBackend(context);
  const { width = 3, height = 3 } = data;
  const boardWidth = width * TILE_PX + (width - 1) * GRID_GAP;
  const boardHeight = height * TILE_PX + (height - 1) * GRID_GAP;
  const windowWidth = clamp(
    boardWidth + WINDOW_CHROME_W,
    MIN_WIDTH,
    MAX_WIDTH,
  );
  const windowHeight = clamp(
    boardHeight + WINDOW_CHROME_H,
    MIN_HEIGHT,
    MAX_HEIGHT,
  );
  return (
    <Window width={windowWidth} height={windowHeight}>
      <Window.Content>
        <SlidingPuzzleContent />
      </Window.Content>
    </Window>
  );
};

export const SlidingPuzzleContent = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    board = [],
    width = 3,
    height = 3,
    pending_width = 3,
    pending_height = 3,
    min_size,
    max_size,
    tile_images = {},
    game_status,
    move_count,
    tickets,
    time_string,
    source_label,
    is_cabinet,
    has_photo_loaded,
    available_photos = [],
  } = data;
  const blankId = width * height;
  const started = game_status !== 2;

  return (
    <Stack fill vertical>
      <Stack.Item>
        <Section title="Sliding Puzzle" textAlign="center">
          <Box>
            <b>Photo: </b>
            {truncateLabel(source_label)}
          </Box>
          <Box>
            {started && (
              <>
                <b>Moves: </b>
                {move_count}
                <b> Time: </b>
                {time_string}
                <b> </b>
              </>
            )}
            <b>Tickets: </b>
            {tickets}
          </Box>
        </Section>
      </Stack.Item>
      <Stack.Item grow>
        <Section fill scrollable scrollableHorizontal textAlign="center">
          {game_status === 1 && (
            <Box color="good" bold mb={1}>
              Solved! The picture is complete.
            </Box>
          )}
          {started ? (
            <Box
              inline
              style={{
                display: 'inline-grid',
                'grid-template-columns': `repeat(${width}, ${TILE_PX}px)`,
                'grid-template-rows': `repeat(${height}, ${TILE_PX}px)`,
                gap: '2px',
              }}
            >
              {board.map((tileId, index) => {
                if (tileId === blankId) {
                  return (
                    <Box
                      key={index}
                      width={`${TILE_PX}px`}
                      height={`${TILE_PX}px`}
                    />
                  );
                }
                return (
                  <Box
                    key={index}
                    lineHeight={0}
                    onClick={() => act('PRG_move', { index: index + 1 })}
                  >
                    <img
                      src={`data:image/png;base64,${tile_images[tileId]}`}
                      width={TILE_PX}
                      height={TILE_PX}
                    />
                  </Box>
                );
              })}
            </Box>
          ) : (
            <Box color="label" mt={4}>
              Configure a size below and press New Game to begin.
            </Box>
          )}
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section textAlign="center">
          {!is_cabinet && (
            <Box mb={1}>
              {available_photos.length ? (
                available_photos.map((photo) => (
                  <Button
                    key={photo.index}
                    content={truncateLabel(photo.name)}
                    onClick={() =>
                      act('PRG_select_photo', { index: photo.index })
                    }
                  />
                ))
              ) : (
                <Box color="label">No photos stored. Library photo will be used.</Box>
              )}
            </Box>
          )}
          {is_cabinet && (
            <Box mb={1} color="label">
              {has_photo_loaded
                ? 'Photo loaded. Eject it to get it back.'
                : 'Insert a photo, or library/default will be used.'}
            </Box>
          )}
          <NumberInput
            inline
            animated
            unit=" Width"
            minValue={min_size}
            maxValue={max_size}
            step={1}
            stepPixelSize={10}
            width="48px"
            value={pending_width}
            onChange={(value) => act('PRG_set_size', { width: value })}
          />
          <NumberInput
            inline
            animated
            color="blue"
            unit=" Height"
            minValue={min_size}
            maxValue={max_size}
            step={1}
            stepPixelSize={10}
            width="48px"
            value={pending_height}
            onChange={(value) => act('PRG_set_size', { height: value })}
          />
          <Box mt={1}>
            <Button
              content="New Game"
              color="blue"
              onClick={() => act('PRG_new_game')}
            />
            <Button
              content="Eject Photo"
              color="bad"
              disabled={!has_photo_loaded}
              onClick={() => act('PRG_eject_photo')}
            />
            {is_cabinet && (
              <Button
                content="Claim Tickets"
                color="green"
                disabled={!tickets}
                onClick={() => act('PRG_tickets')}
              />
            )}
          </Box>
        </Section>
      </Stack.Item>
    </Stack>
  );
};
