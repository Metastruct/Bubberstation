import {
  Box,
  Button,
  ByondUi,
  NoticeBox,
  ProgressBar,
  Section,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

export const Gateway = () => {
  return (
    <Window width={350} height={440}>
      <Window.Content scrollable>
        <GatewayContent />
      </Window.Content>
    </Window>
  );
};

const GatewayContent = (props) => {
  const { act, data } = useBackend();
  const {
    gateway_present = false,
    gateway_status = false,
    current_target = null,
    destinations = [],
    gateway_mapkey,
  } = data;
  if (!gateway_present) {
    return (
      <Section>
        <NoticeBox>No linked gateway</NoticeBox>
        <Button fluid onClick={() => act('linkup')}>
          Linkup
        </Button>
      </Section>
    );
  }
  // META EDIT - CHANGE - START - GATEWAY_PREVIEW_REMOUNT_ZOOM_BUG
  // ByondUi used to only be mounted while current_target was set, getting
  // unmounted/remounted every time the gateway (de)activated. Its native map
  // control only measures its pixel size once on mount, so each remount was
  // liable to grab a stale/mid-layout size, leaving the preview a tiny sliver
  // or a single tile blown up to fill the box. CameraConsole.tsx never
  // unmounts its ByondUi for this exact reason, so match that here: keep it
  // mounted permanently and let the DM-side static/scanline state (already
  // implemented for the no-destination case) show instead of tearing it down.
  /* ORIGINAL:
  if (current_target) {
    return (
      <Section title={current_target.name}>
        <ByondUi
          height="320px"
          params={{
            id: gateway_mapkey,
            type: 'map',
          }}
        />
        <Button
          mt="2px"
          textAlign="center"
          fluid
          onClick={() => act('deactivate')}
        >
          Deactivate
        </Button>
      </Section>
    );
  }
  if (!destinations.length) {
    return <Section>No gateway nodes detected.</Section>;
  }
  return (
    <>
      {!gateway_status && <NoticeBox>Gateway Unpowered</NoticeBox>}
      {destinations.map((dest) => (
        <Section key={dest.ref} title={dest.name}>
          {(dest.available && (
            <Button
              fluid
              onClick={() =>
                act('activate', {
                  destination: dest.ref,
                })
              }
            >
              Activate
            </Button>
          )) || (
            <>
              <Box m={1} textColor="bad">
                {dest.reason}
              </Box>
              {!!dest.timeout && (
                <ProgressBar value={dest.timeout}>Calibrating...</ProgressBar>
              )}
            </>
          )}
        </Section>
      ))}
    </>
  );
  */
  return (
    <Section title={current_target?.name ?? 'No Destination'}>
      <ByondUi
        height="320px"
        params={{
          id: gateway_mapkey,
          type: 'map',
        }}
      />
      {current_target ? (
        <Button
          mt="2px"
          textAlign="center"
          fluid
          onClick={() => act('deactivate')}
        >
          Deactivate
        </Button>
      ) : !destinations.length ? (
        <Box mt={1}>No gateway nodes detected.</Box>
      ) : (
        <>
          {!gateway_status && <NoticeBox>Gateway Unpowered</NoticeBox>}
          {destinations.map((dest) => (
            <Section key={dest.ref} title={dest.name} mt={1}>
              {(dest.available && (
                <Button
                  fluid
                  onClick={() =>
                    act('activate', {
                      destination: dest.ref,
                    })
                  }
                >
                  Activate
                </Button>
              )) || (
                <>
                  <Box m={1} textColor="bad">
                    {dest.reason}
                  </Box>
                  {!!dest.timeout && (
                    <ProgressBar value={dest.timeout}>
                      Calibrating...
                    </ProgressBar>
                  )}
                </>
              )}
            </Section>
          ))}
        </>
      )}
    </Section>
  );
  // META EDIT - CHANGE - END - GATEWAY_PREVIEW_REMOUNT_ZOOM_BUG
};
