/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { Section, Stack, Tabs } from 'tgui-core/components';
import { ChatPageSettings } from '../chat/ChatPageSettings';
import { SETTINGS_TABS } from './constants';
import { SettingsGeneral } from './SettingsGeneral';
import { SettingsStatPanel } from './SettingsStatPanel';
import { SettingsWebsocket } from './SettingsWebsocket';
import { TextHighlightSettings } from './TextHighlight';
import { useSettings } from './use-settings';

export function SettingsPanel(props) {
  const {
    settings: { view },
    updateSettings,
  } = useSettings();
  const { activeTab } = view;

  return (
    <Stack fill>
      <Stack.Item>
        <Section fitted fill minHeight="8em">
          <Tabs vertical>
            {SETTINGS_TABS.map((tab) => (
              <Tabs.Tab
                key={tab.id}
                selected={tab.id === activeTab}
                onClick={() =>
                  updateSettings({
                    view: {
                      ...view,
                      activeTab: tab.id,
                    },
                  })
                }
              >
                {tab.name}
              </Tabs.Tab>
            ))}
          </Tabs>
        </Section>
      </Stack.Item>
      {/* META EDIT - CHANGE - START - LAYOUT_HORIZONTAL_OVERFLOW */}
      {/* ORIGINAL: <Stack.Item grow basis={0}> */}
      {/* This Stack isn't wrapped in a Layout__content like the chat pane is, so a too-wide tab (e.g. Text
          Highlights' checkbox row) had nowhere to overflow into except invisibly past the window edge.
          overflowX makes this item scroll instead, and also stops it forcing the whole Stack wider. */}
      <Stack.Item grow basis={0} overflowX="auto">
        {activeTab === 'general' && <SettingsGeneral />}
        {activeTab === 'chatPage' && <ChatPageSettings />}
        {activeTab === 'textHighlight' && <TextHighlightSettings />}
        {activeTab === 'statPanel' && <SettingsStatPanel />}
        {activeTab === 'websocket' && <SettingsWebsocket />}
      </Stack.Item>
      {/* META EDIT - CHANGE - END */}
    </Stack>
  );
}
