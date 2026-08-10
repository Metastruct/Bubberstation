import { Box, Button, NumberInput, Section, Stack } from 'tgui-core/components';
import { clamp } from 'tgui-core/math';

import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';

const MAX_WIDTH = 700;
const MAX_HEIGHT = 600;
const MIN_WIDTH = 420;
const MIN_HEIGHT = 320;
// Native sprite size of each board tile.
const TILE_PX = 16;
const WINDOW_CHROME_H = 44;
const WINDOW_CHROME_W = 24;
const HEADER_HEIGHT = 80;
const FOOTER_HEIGHT = 64;
const KNOB_ROW_HEIGHT = 40;
const SECTION_GAP = 12;
const BOARD_PADDING = 16;

export const Minesweeper = (props, context) => {
  const { data } = useBackend(context);
  const { board_data = [], difficulty } = data;
  const cols = board_data.length || 10;
  const rows = board_data[0]?.length || 10;
  const knobRow = difficulty === 'Custom' ? KNOB_ROW_HEIGHT : 0;
  const width = clamp(cols * TILE_PX + WINDOW_CHROME_W, MIN_WIDTH, MAX_WIDTH);
  const height = clamp(
    WINDOW_CHROME_H +
      HEADER_HEIGHT +
      SECTION_GAP +
      BOARD_PADDING +
      rows * TILE_PX +
      FOOTER_HEIGHT +
      knobRow,
    MIN_HEIGHT,
    MAX_HEIGHT,
  );
  return (
    <Window width={width} height={height}>
      <Window.Content>
        <MinesweeperContent />
      </Window.Content>
    </Window>
  );
};

export const MinesweeperContent = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    board_data = [],
    game_status,
    difficulty,
    current_difficulty,
    emagged,
    flag_mode,
    tickets,
    custom_width,
    custom_height,
    custom_mines,
    flags,
    current_mines,
    time_string,
  } = data;
  return (
    <Stack fill vertical>
      <Stack.Item>
        <Section
          title={`Minesweeper ${emagged ? ' EXTREME EDITION' : ''}`}
          color={emagged ? 'bad' : 'primary'}
          textAlign="center"
        >
          <b>DIFFICULTY: </b>
          {current_difficulty}
          <br />
          <b>
            {emagged
              ? 'Explode in the game, explode in real life!'
              : 'Tickets: '}
          </b>
          {emagged ? '' : tickets}
          <b>{emagged ? '' : ' Mines left: '}</b>
          {emagged ? '' : current_mines - flags}
          <b>{emagged ? '' : ' Time: '}</b>
          {emagged ? '' : time_string}
        </Section>
      </Stack.Item>
      <Stack.Item grow>
        <Section fill scrollable scrollableHorizontal textAlign="center">
          {game_status !== 3 ? (
            <Box nowrap>
              {board_data.map((xdata, xind) => (
                <Box inline key={`outer${xind}`}>
                  {xdata.map((imagec, yind) => (
                    <Box key={`${xind},${yind}`}>
                      {imagec ? (
                        <Box
                          lineHeight={0}
                          onClick={() =>
                            act('PRG_do_tile', {
                              x: xind + 1,
                              y: yind + 1,
                              flag: false,
                            })
                          }
                          onContextMenu={(eve) => {
                            eve.preventDefault();
                            act('PRG_do_tile', {
                              x: xind + 1,
                              y: yind + 1,
                              flag: true,
                            });
                          }}
                        >
                          <img src={resolveAsset(imagec)} />
                        </Box>
                      ) : (
                        ''
                      )}
                    </Box>
                  ))}
                </Box>
              ))}
            </Box>
          ) : (
            <Box>
              <br />
              <br />
              <br />
              <br />
              <br />
              <br />
              <br />
              <br />
              <br />
              <br />
              <br />
            </Box>
          )}
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section textAlign="center">
          <Button
            content="Toggle Flagging"
            color={flag_mode ? 'green' : 'blue'}
            onClick={() => act('PRG_toggle_flag')}
          />
          <Button
            content="New Game"
            color="blue"
            onClick={() => act('PRG_new_game')}
          />
          <br />
          <Button
            content="Beginner"
            selected={difficulty === 'Beginner'}
            color="blue"
            onClick={() =>
              act('PRG_difficulty', {
                difficulty: 1,
              })
            }
          />
          <Button
            content="Intermediate"
            selected={difficulty === 'Intermediate'}
            color="blue"
            onClick={() =>
              act('PRG_difficulty', {
                difficulty: 2,
              })
            }
          />
          <Button
            content="Expert"
            selected={difficulty === 'Expert'}
            color="blue"
            onClick={() =>
              act('PRG_difficulty', {
                difficulty: 3,
              })
            }
          />
          <Button
            content="Custom"
            selected={difficulty === 'Custom'}
            color="blue"
            onClick={() =>
              act('PRG_difficulty', {
                difficulty: 4,
              })
            }
          />
          {difficulty === 'Custom' ? (
            <Box mt={1}>
              <NumberInput
                inline
                animated
                unit=" Width"
                minValue={5}
                maxValue={100}
                step={1}
                stepPixelSize={10}
                width="48px"
                value={custom_width}
                onChange={(value) =>
                  act('PRG_width', {
                    width: value,
                  })
                }
              />
              <NumberInput
                inline
                animated
                color="blue"
                unit=" Height"
                minValue={5}
                maxValue={100}
                step={1}
                stepPixelSize={10}
                width="48px"
                value={custom_height}
                onChange={(value) =>
                  act('PRG_height', {
                    height: value,
                  })
                }
              />
              <NumberInput
                inline
                animated
                color="bad"
                unit=" Mines"
                minValue={5}
                maxValue={2000}
                step={5}
                stepPixelSize={4}
                width="60px"
                value={custom_mines}
                onChange={(value) =>
                  act('PRG_mines', {
                    mines: value,
                  })
                }
              />
            </Box>
          ) : (
            ''
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
};
