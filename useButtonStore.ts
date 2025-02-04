// store/useButtonStore.ts
import {create} from 'zustand';
 
type Store = {
  /**
   * 结构说明：
   * - 第一层 key: section ID
   * - 值包含：
   *   selectedRow: 当前选中行 ID
   *   selectedButtons: 该行中被选中的按钮ID集合
   */
  selections: Record<number, {
    selectedRow: number | null;
    selectedButtons: string[];
  }>;
  actions: {
    toggleButton: (sectionId: number, rowId: number, buttonId: string) => void;
  };
};

export const useButtonStore = create<Store>((set) => ({
  selections: {},
  actions: {
    toggleButton: (sectionId, rowId, buttonId) => set((state) => {
      const current = state.selections[sectionId] || {
        selectedRow: null,
        selectedButtons: []
      };

      // 情况1：点击的是新行
      if (current.selectedRow !== rowId) {
        return {
          selections: {
            ...state.selections,
            [sectionId]: {
              selectedRow: rowId,
              selectedButtons: [buttonId] // 新行默认选中当前按钮
            }
          }
        };
      }

      // 情况2：点击的是已选中的行
      const isSelected = current.selectedButtons.includes(buttonId);
      return {
        selections: {
          ...state.selections,
          [sectionId]: {
            selectedRow: rowId,
            selectedButtons: isSelected
              ? current.selectedButtons.filter(id => id !== buttonId)
              : [...current.selectedButtons, buttonId]
          }
        }
      };
    }),
  },
}));
