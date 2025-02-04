// components/SectionList.tsx
import React, {useCallback} from 'react';
import {View, FlatList} from 'react-native';
import ButtonItem from './ButtonItem';

const Row = React.memo(
  ({sectionId, rowId}: {sectionId: number; rowId: number}) => (
    <View style={{flexDirection: 'row'}}>
      {Array.from({length: 5}).map((_, idx) => (
        <ButtonItem
          key={`btn-${idx}`}
          sectionId={sectionId}
          rowId={rowId}
          buttonId={`s${sectionId}-r${rowId}-b${idx}`}
          label={`B${idx}`}
        />
      ))}
    </View>
  ),
);

const Section = React.memo(({sectionId}: {sectionId: number}) => {
  const renderRow = useCallback(
    ({item: rowId}: {item: number}) => (
      <Row sectionId={sectionId} rowId={rowId} />
    ),
    [sectionId],
  );

  return (
    <FlatList
      data={Array.from({length: 10}, (_, i) => i)}
      renderItem={renderRow}
      keyExtractor={rowId => `row-${sectionId}-${rowId}`}
      initialNumToRender={5}
      windowSize={7}
      maxToRenderPerBatch={8}
    />
  );
});

const SectionList = () => {
  const renderSection = useCallback(
    ({item: sectionId}: {item: number}) => <Section sectionId={sectionId} />,
    [],
  );

  return (
    <FlatList
      data={Array.from({length: 10}, (_, i) => i)}
      renderItem={renderSection}
      keyExtractor={sectionId => `section-${sectionId}`}
      initialNumToRender={3}
      ItemSeparatorComponent={() => (
        <View style={{height: 20, backgroundColor: 'transparent'}} />
      )}
      windowSize={5}
      maxToRenderPerBatch={4}
    />
  );
};
export default SectionList;
