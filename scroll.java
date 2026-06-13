private int scrollAccumulator = 0; // 滚动累加器
private static final int TRIGGER_THRESHOLD = 20; // 触发阈值（可适当调大一点，比如 20-30 像素，体验更佳）

private void setupScrollListener() {
    recyclerView.addOnScrollListener(new RecyclerView.OnScrollListener() {
        @Override
        public void onScrolled(@NonNull RecyclerView recyclerView, int dx, int dy) {
            super.onScrolled(recyclerView, dx, dy);

            if (isInitialScroll) return;

            // 1. 将当前的增量直接累加
            scrollAccumulator += dy;

            // 2. 限制累加器的范围在 [-TRIGGER_THRESHOLD, TRIGGER_THRESHOLD] 之间
            // 这可以防止用户在一个方向滑动了极长距离后，反向滑动时需要滑同样长的距离才能响应
            if (scrollAccumulator > TRIGGER_THRESHOLD) {
                scrollAccumulator = TRIGGER_THRESHOLD;
            } else if (scrollAccumulator < -TRIGGER_THRESHOLD) {
                scrollAccumulator = -TRIGGER_THRESHOLD;
            }

            // 3. 根据边界值触发状态切换
            if (scrollAccumulator == -TRIGGER_THRESHOLD) {
                // 达到了向下的极限位移 -> 变为绝对布局（置顶）
                animateRecyclerViewMargin(true);
            } else if (scrollAccumulator == TRIGGER_THRESHOLD) {
                // 达到了向上的极限位移 -> 变为相对布局（恢复原位）
                animateRecyclerViewMargin(false);
            }
        }
    });
}
