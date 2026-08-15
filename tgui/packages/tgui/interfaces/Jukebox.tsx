// META EDIT - CHANGE - START - JUKEBOX_SEARCH_UI
/* ORIGINAL:
import { sortBy } from 'es-toolkit';
import {
  Box,
  Button,
  Dropdown,
  Knob,
  LabeledControls,
  LabeledList,
  Section,
} from 'tgui-core/components';
*/
import { sortBy } from 'es-toolkit';
import { useMemo, useState } from 'react';
import {
  Box,
  Button,
  Input,
  Knob,
  LabeledControls,
  LabeledList,
  Section,
  Stack,
  VirtualList,
} from 'tgui-core/components';
// META EDIT - CHANGE - END - JUKEBOX_SEARCH_UI
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Song = {
  name: string;
  length: number;
  beat: number;
};

type Data = {
  active: BooleanLike;
  looping: BooleanLike;
  volume: number;
  track_selected: string | null;
  songs: Song[];
};

export const Jukebox = () => {
  const { act, data } = useBackend<Data>();
  const { active, looping, track_selected, volume, songs } = data;

  // META EDIT - ADDITION - START - JUKEBOX_SEARCH_UI
  const [query, setQuery] = useState('');
  // META EDIT - ADDITION - END - JUKEBOX_SEARCH_UI

  // META EDIT - CHANGE - START - JUKEBOX_SEARCH_UI
  /* ORIGINAL: const songs_sorted: Song[] = sortBy(songs, [(song: Song) => song.name]); */
  const songs_sorted: Song[] = useMemo(
    () => sortBy(songs, [(song: Song) => song.name.toLowerCase()]),
    [songs],
  );
  // META EDIT - CHANGE - END - JUKEBOX_SEARCH_UI
  const song_selected: Song | undefined = songs.find(
    (song) => song.name === track_selected,
  );

  // META EDIT - ADDITION - START - JUKEBOX_SEARCH_UI
  const filtered_songs = useMemo(() => {
    if (!query) {
      return songs_sorted;
    }
    const lower_query = query.toLowerCase();
    return songs_sorted.filter((song) =>
      song.name.toLowerCase().includes(lower_query),
    );
  }, [songs_sorted, query]);

  function selectTrack(name: string): void {
    if (active) {
      return;
    }
    act('select_track', { track: name });
  }
  // META EDIT - ADDITION - END - JUKEBOX_SEARCH_UI

  // META EDIT - CHANGE - START - JUKEBOX_SEARCH_UI
  /* ORIGINAL:
  return (
    <Window width={370} height={313}>
      <Window.Content>
        <Section
          title="Song Player"
          buttons={
            <>
              <Button
                icon={active ? 'pause' : 'play'}
                content={active ? 'Stop' : 'Play'}
                selected={active}
                onClick={() => act('toggle')}
              />
              <Button.Checkbox
                icon={'arrow-rotate-left'}
                content="Repeat"
                disabled={active}
                checked={looping}
                onClick={() => act('loop', { looping: !looping })}
              />
            </>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Track Selected">
              <Dropdown
                width="240px"
                options={songs_sorted.map((song) => song.name)}
                disabled={!!active}
                selected={song_selected?.name || 'Select a Track'}
                onSelected={(value) =>
                  act('select_track', {
                    track: value,
                  })
                }
              />
            </LabeledList.Item>
            <LabeledList.Item label="Track Length">
              {song_selected?.length || 'No Track Selected'}
            </LabeledList.Item>
            <LabeledList.Item label="Track Beat">
              {song_selected?.beat || 'No Track Selected'}
              {song_selected?.beat === 1 ? ' beat' : ' beats'}
            </LabeledList.Item>
          </LabeledList>
        </Section>
        <Section title="Machine Settings">
          <LabeledControls justify="center">
            <LabeledControls.Item label="Volume">
              <Box position="relative">
                <Knob
                  size={3.2}
                  color={volume >= 25 ? 'red' : 'green'}
                  value={volume}
                  unit="%"
                  minValue={0}
                  maxValue={50}
                  step={1}
                  stepPixelSize={1}
                  onChange={(e, value) =>
                    act('set_volume', {
                      volume: value,
                    })
                  }
                />
                <Button
                  fluid
                  position="absolute"
                  top="-2px"
                  right="-22px"
                  color="transparent"
                  icon="fast-backward"
                  onClick={() =>
                    act('set_volume', {
                      volume: 'min',
                    })
                  }
                />
                <Button
                  fluid
                  position="absolute"
                  top="16px"
                  right="-22px"
                  color="transparent"
                  icon="fast-forward"
                  onClick={() =>
                    act('set_volume', {
                      volume: 'max',
                    })
                  }
                />
                <Button
                  fluid
                  position="absolute"
                  top="34px"
                  right="-22px"
                  color="transparent"
                  icon="undo"
                  onClick={() =>
                    act('set_volume', {
                      volume: 'reset',
                    })
                  }
                />
              </Box>
            </LabeledControls.Item>
          </LabeledControls>
        </Section>
      </Window.Content>
    </Window>
  );
  */
  return (
    <Window width={380} height={470}>
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section title="Song Player">
              <LabeledList>
                <LabeledList.Item label="Track Selected">
                  {song_selected?.name || 'No Track Selected'}
                </LabeledList.Item>
                <LabeledList.Item label="Track Length">
                  {song_selected?.length || 'No Track Selected'}
                </LabeledList.Item>
                <LabeledList.Item label="Track Beat">
                  {song_selected?.beat || 'No Track Selected'}
                  {song_selected?.beat === 1 ? ' beat' : ' beats'}
                </LabeledList.Item>
              </LabeledList>
              <Box mt={1}>
                <Input
                  fluid
                  expensive
                  disabled={!!active}
                  placeholder={`Search ${songs_sorted.length} tracks...`}
                  value={query}
                  onChange={(value) => setQuery(value)}
                />
              </Box>
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Section fill scrollable>
              <VirtualList>
                {filtered_songs.map((song) => (
                  <Box
                    key={song.name}
                    className="candystripe"
                    p="2px 4px"
                    color={song.name === track_selected ? 'black' : undefined}
                    backgroundColor={
                      song.name === track_selected ? 'white' : undefined
                    }
                    style={{
                      cursor: active ? 'not-allowed' : 'pointer',
                    }}
                    onClick={() => selectTrack(song.name)}
                  >
                    {song.name}
                  </Box>
                ))}
              </VirtualList>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Machine Settings">
              <LabeledControls justify="center">
                <LabeledControls.Item label="Volume">
                  <Box position="relative" width="126px" height="100px">
                    <Knob
                      ml="26px"
                      size={3.2}
                      color={volume >= 25 ? 'red' : 'green'}
                      value={volume}
                      unit="%"
                      minValue={0}
                      maxValue={50}
                      step={1}
                      stepPixelSize={1}
                      onChange={(e, value) =>
                        act('set_volume', {
                          volume: value,
                        })
                      }
                    />
                    <Button
                      fluid
                      position="absolute"
                      top="-2px"
                      left="2px"
                      color="transparent"
                      icon="fast-backward"
                      onClick={() =>
                        act('set_volume', {
                          volume: 'min',
                        })
                      }
                    />
                    <Button
                      fluid
                      position="absolute"
                      top="16px"
                      left="2px"
                      color="transparent"
                      icon="fast-forward"
                      onClick={() =>
                        act('set_volume', {
                          volume: 'max',
                        })
                      }
                    />
                    <Button
                      fluid
                      position="absolute"
                      top="34px"
                      left="2px"
                      color="transparent"
                      icon="undo"
                      onClick={() =>
                        act('set_volume', {
                          volume: 'reset',
                        })
                      }
                    />
                  </Box>
                </LabeledControls.Item>
                <LabeledControls.Item label="Playback">
                  <Stack>
                    <Stack.Item>
                      <Button
                        color={active ? 'bad' : 'transparent'}
                        tooltip={active ? 'Stop' : 'Play'}
                        tooltipPosition="top"
                        icon={active ? 'pause' : 'play'}
                        iconSize={4}
                        verticalAlignContent="middle"
                        disabled={!song_selected}
                        onClick={() => act('toggle')}
                        width="100px"
                        height="100px"
                        style={{ borderRadius: '12px' }}
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <Button.Checkbox
                        color={looping ? 'green' : 'transparent'}
                        tooltip="Repeat"
                        tooltipPosition="top"
                        icon="arrow-rotate-left"
                        iconSize={4}
                        verticalAlignContent="middle"
                        checked={looping}
                        onClick={() => {
                          if (active) {
                            return;
                          }
                          act('loop', { looping: !looping });
                        }}
                        width="100px"
                        height="100px"
                        style={{
                          borderRadius: '12px',
                          cursor: active ? 'not-allowed' : 'pointer',
                          opacity: active ? 0.6 : 1,
                        }}
                      />
                    </Stack.Item>
                  </Stack>
                </LabeledControls.Item>
              </LabeledControls>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
  // META EDIT - CHANGE - END - JUKEBOX_SEARCH_UI
};
