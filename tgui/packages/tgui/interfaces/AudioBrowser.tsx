import { useEffect, useMemo, useState } from 'react';
import {
  Autofocus,
  Box,
  Button,
  Input,
  Section,
  Stack,
  VirtualList,
} from 'tgui-core/components';
import { fetchRetry } from 'tgui-core/http';
import { KEY_DOWN, KEY_ENTER, KEY_UP } from 'tgui-core/keycodes';
import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { logger } from '../logging';

function copyText(text: string): void {
  const input = document.createElement('input');
  input.value = text;
  document.body.appendChild(input);
  input.select();
  document.execCommand('copy');
  document.body.removeChild(input);
}

export function AudioBrowser() {
  const { act } = useBackend();

  const [sounds, setSounds] = useState<string[]>([]);
  const [query, setQuery] = useState('');
  const [selected, setSelected] = useState(0);
  const [copiedPath, setCopiedPath] = useState<string | null>(null);

  useEffect(() => {
    fetchRetry(resolveAsset('audio_browser_sounds.json'))
      .then((response) => response.json())
      .then((data: string[]) => setSounds(data))
      .catch((error) => {
        logger.log(
          'Failed to fetch audio_browser_sounds.json',
          JSON.stringify(error),
        );
      });
  }, []);

  const filteredSounds = useMemo(() => {
    if (query.length === 0) return sounds;
    const lowerQuery = query.toLowerCase();
    return sounds.filter((path) => path.toLowerCase().includes(lowerQuery));
  }, [query, sounds]);

  function handlePreview(path?: string): void {
    if (!path) return;
    act('preview', { path });
  }

  function handleCopy(path?: string): void {
    if (!path) return;
    copyText(path);
    setCopiedPath(path);
  }

  function handleSearch(newQuery: string): void {
    if (newQuery === query) return;
    setQuery(newQuery);
    setSelected(0);
  }

  function handleArrowKey(key: number): void {
    if (!filteredSounds.length) return;
    const len = filteredSounds.length - 1;
    if (key === KEY_DOWN) {
      const next = selected >= len ? 0 : selected + 1;
      setSelected(next);
      document
        ?.getElementById(next.toString())
        ?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    } else if (key === KEY_UP) {
      const prev = selected <= 0 ? len : selected - 1;
      setSelected(prev);
      document
        ?.getElementById(prev.toString())
        ?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
  }

  function handleKeyDown(event: React.KeyboardEvent<HTMLDivElement>): void {
    const keyCode = window.event ? event.which : event.keyCode;
    if (keyCode === KEY_DOWN || keyCode === KEY_UP) {
      event.preventDefault();
      handleArrowKey(keyCode);
    }
    if (keyCode === KEY_ENTER) {
      event.preventDefault();
      handlePreview(filteredSounds[selected]);
    }
  }

  return (
    <Window title="Audio Browser" width={500} height={550}>
      <Window.Content onKeyDown={handleKeyDown}>
        <Stack fill vertical>
          <Stack.Item>
            <Input
              autoFocus
              autoSelect
              expensive
              fluid
              onChange={handleSearch}
              placeholder={`Search ${sounds.length} sounds...`}
              value={query}
            />
          </Stack.Item>
          <Stack.Item grow>
            <Section fill scrollable>
              <Autofocus />
              <VirtualList>
                {filteredSounds.map((path, index) => (
                  <Stack
                    key={path}
                    id={index.toString()}
                    className="candystripe"
                    align="center"
                    fill
                    onClick={() => setSelected(index)}
                    onDoubleClick={() => handlePreview(path)}
                    style={{ padding: '2px 4px' }}
                  >
                    <Stack.Item grow>
                      <Box
                        color={index === selected ? 'black' : undefined}
                        backgroundColor={
                          index === selected ? 'white' : undefined
                        }
                        style={{ wordBreak: 'break-all' }}
                      >
                        {path}
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        icon="play"
                        tooltip="Preview"
                        onClick={() => handlePreview(path)}
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        icon={copiedPath === path ? 'check' : 'copy'}
                        tooltip="Copy path"
                        onClick={() => handleCopy(path)}
                      />
                    </Stack.Item>
                  </Stack>
                ))}
              </VirtualList>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
}
