// THIS IS A META UI FILE
import { NtosWindow } from '../layouts';
import { SlidingPuzzleContent } from './SlidingPuzzle';

export const NtosSlidingPuzzle = (props, context) => {
  return (
    <NtosWindow width={600} height={620}>
      <NtosWindow.Content>
        <SlidingPuzzleContent />
      </NtosWindow.Content>
    </NtosWindow>
  );
};
