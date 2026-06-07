    static class TagView extends ViewGroup {

        private final TextView textView;
        private final ImageView imageView;
        private final int textPaddingTopDp = 2;  // TextView 上下内边距
        private final int textPaddingBottomDp = 2;
        private final int marginLeftDp = 4;      // TextView 左边距
        private final int marginRightDp = 4;     // ImageView 右边距

        /** 背景颜色 */
        private int backgroundColor = Color.parseColor("#eee112");
        /** 最大圆角半径(dp) */
        private float maxCornerRadiusDp = 8f;

        TagView(Context context) {
            super(context);

            // --- TextView ---
            textView = new TextView(context);
            textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 11);
            textView.setTextColor(Color.parseColor("#374151"));
            textView.setSingleLine(false);       // 支持换行
            textView.setMaxLines(3);              // 最多 3 行（可按需调整）
            textView.setEllipsize(android.text.TextUtils.TruncateAt.END);
            // 设置上下内边距 2dp
            int padV = (int) TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP, textPaddingTopDp,
                    context.getResources().getDisplayMetrics());
            textView.setPadding(0, padV, 0, padV);

            LayoutParams tvLp = new LayoutParams(
                    LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
            addView(textView, tvLp);

            // --- ImageView ---
            imageView = new ImageView(context);
            imageView.setScaleType(ImageView.ScaleType.FIT_CENTER);
            int iconSize = (int) TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP, 11,
                    context.getResources().getDisplayMetrics());
            LayoutParams ivLp = new LayoutParams(iconSize, iconSize);
            addView(imageView, ivLp);
        }

        /** 设置标签文本 */
        void setTagText(String text) {
            textView.setText(text);
        }

        /** 设置图标 */
        void setTagIcon(Drawable drawable) {
            imageView.setImageDrawable(drawable);
        }

        /** 设置图标资源 ID */
        void setTagIconRes(int resId) {
            imageView.setImageResource(resId);
        }

        @Override
        protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
            int widthLimit = MeasureSpec.getSize(widthMeasureSpec) - dp(marginLeftDp) - dp(marginRightDp);
            int widthMode = MeasureSpec.getMode(widthMeasureSpec);

            // 测量 ImageView（固定尺寸）
            measureChild(imageView,
                    MeasureSpec.makeMeasureSpec(imageView.getLayoutParams().width, MeasureSpec.EXACTLY),
                    MeasureSpec.makeMeasureSpec(imageView.getLayoutParams().height, MeasureSpec.EXACTLY));

            // 测量 TextView：宽度为剩余空间（减去 ImageView 宽度 + 间距）
            int availableWidthForText = widthLimit - imageView.getMeasuredWidth() - dp(4);
            measureChild(textView,
                    MeasureSpec.makeMeasureSpec(Math.max(availableWidthForText, dp(40)), MeasureSpec.AT_MOST),
                    MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED));

            int totalHeight = Math.max(textView.getMeasuredHeight(), imageView.getMeasuredHeight());

            int measuredWidth;
            if (widthMode == MeasureSpec.EXACTLY) {
                measuredWidth = MeasureSpec.getSize(widthMeasureSpec);
            } else {
                measuredWidth = dp(marginLeftDp) + textView.getMeasuredWidth()
                        + dp(4) + imageView.getMeasuredWidth() + dp(marginRightDp);
                if (widthMode == MeasureSpec.AT_MOST) {
                    measuredWidth = Math.min(measuredWidth, MeasureSpec.getSize(widthMeasureSpec));
                }
            }

            setMeasuredDimension(measuredWidth, totalHeight);

            // 根据高度动态设置圆角背景
            updateRoundedBackground(totalHeight);
        }

        @Override
        protected void onLayout(boolean changed, int l, int t, int r, int b) {
            int containerHeight = b - t;

            // 布局 TextView: 左边距 4dp，垂直居中
            int textLeft = dp(marginLeftDp);
            int textTop = (containerHeight - textView.getMeasuredHeight()) / 2;
            layoutChild(textView, textLeft, textTop);

            // 布局 ImageView: 与 TextView 最后一行文字垂直居中对齐
            int ivRight = r - l - dp(marginRightDp);
            int ivLeft = ivRight - imageView.getMeasuredWidth();
            int ivTop = calculateImageViewTopAlignedWithLastLine(containerHeight);
            layoutChild(imageView, ivLeft, ivTop);
        }

        /**
         * 计算 ImageView 的 top 位置，使其与 TextView 的最后一行文字垂直居中
         *
         * 核心逻辑：
         *   1. 获取 TextView 最后一行的 bounds（通过 getLineBounds）
         *   2. 将最后一行中心 Y 映射到容器坐标系
         *   3. ImageView 居中对齐到该位置
         */
        private int calculateImageViewTopAlignedWithLastLine(int containerHeight) {
            int lineCount = textView.getLineCount();
            // 单行或无内容：直接整体居中，避免 getLineBounds 的 padding 干扰
            if (lineCount <= 1) {
                return (containerHeight - imageView.getMeasuredHeight()) / 2;
            }

            android.graphics.Rect lastLineRect = new android.graphics.Rect();
            textView.getLineBounds(lineCount - 1, lastLineRect);
            // lastLineRect 是相对于 textView 的坐标

            // 计算最后一行中心点相对于容器的 Y 坐标
            int textTopInContainer = (containerHeight - textView.getMeasuredHeight()) / 2;
            int lastLineCenterY = textTopInContainer + lastLineRect.centerY();

            // ImageView 以该中心点居中
            return lastLineCenterY - imageView.getMeasuredHeight() / 2;
        }

        private void layoutChild(View child, int left, int top) {
            child.layout(left, top, left + child.getMeasuredWidth(), top + child.getMeasuredHeight());
        }

        /**
         * 根据高度动态更新圆角矩形背景
         * - 单行（高度较小时）：圆角 = 高度/2，呈胶囊形
         * - 多行（高度较大时）：圆角取 maxCornerRadiusDp 上限
         */
        private void updateRoundedBackground(int heightPx) {
            float maxRadiusPx = dp(maxCornerRadiusDp);
            // 圆角半径：不超过最大值，且不大于高度的一半
            float radius = Math.min(heightPx / 2f, maxRadiusPx);

            android.graphics.drawable.GradientDrawable bg = new android.graphics.drawable.GradientDrawable();
            bg.setColor(backgroundColor);
            bg.setCornerRadii(new float[]{radius, radius, radius, radius, radius, radius, radius, radius});
            setBackground(bg);
        }

        /** 设置背景颜色 */
        void setBackgroundColorValue(int color) {
            this.backgroundColor = color;
            // 立即刷新背景（如果已测量过）
            if (getMeasuredHeight() > 0) {
                updateRoundedBackground(getMeasuredHeight());
            }
        }

        /** 设置最大圆角半径(dp) */
        void setMaxCornerRadiusDp(float radiusDp) {
            this.maxCornerRadiusDp = radiusDp;
        }

        private int dp(float value) {
            return (int) TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP, value,
                    getResources().getDisplayMetrics());
        }
    }
