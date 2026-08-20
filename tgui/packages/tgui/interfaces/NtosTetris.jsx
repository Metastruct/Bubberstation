// THIS IS A META UI FILE
import { NtosWindow } from '../layouts';
import { TetrisContent } from './Tetris';

export const NtosTetris = (props, context) => {
  return (
    <NtosWindow width={410} height={635}>
      <NtosWindow.Content>
        <TetrisContent />
      </NtosWindow.Content>
    </NtosWindow>
  );
};
