// components/ButtonItem.tsx
import React from 'react';
import {TouchableOpacity, Text} from 'react-native';
import {useButtonStore} from '../store/useButtonStore';
import {useShallow} from 'zustand/react/shallow';

const ButtonItem = React.memo(
  ({
    sectionId,
    rowId,
    buttonId,
    label,
  }: {
    sectionId: number;
    rowId: number;
    buttonId: string;
    label: string;
  }) => {
    // 精准选择需要的数据
    const [isSelected, actions] = useButtonStore(
      useShallow(state => {
        const section = state.selections[sectionId] || {
          selectedRow: null,
          selectedButtons: [],
        };
        return [
          section.selectedRow === rowId &&
            section.selectedButtons.includes(buttonId),
          state.actions,
        ];
      }),
    );

    return (
      <TouchableOpacity
        onPress={() => actions.toggleButton(sectionId, rowId, buttonId)}
        style={{
          padding: 10,
          backgroundColor: isSelected ? 'blue' : 'gray',
          margin: 2,
        }}>
        <Text style={{color: 'white'}}>{label}</Text>
      </TouchableOpacity>
    );
  },
);

export default ButtonItem;
