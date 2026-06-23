 static class TagView2 extends ViewGroup {

        private final int paddingDp = 2;  // 左右边距
        private final int iconRightMarginDp = 2;  // icon 距父视图右边距
        private final int iconTextGapDp = 2;       // 文字右边距 icon 左边距
        private final List<TextView> textViews = new ArrayList<>();
        private final ImageView imageView;

        /** 背景颜色 */
        private int backgroundColor = Color.parseColor("#EEE121");
        /** 最大圆角半径(dp) */
        private float maxCornerRadiusDp = 8f;
        /** 当前文字字号（sp） */
        private float textSizeSp = 10f;
        /** 当前文字颜色 */
        private int textColor = Color.parseColor("#374151");
        /** 行间距(dp) */
        private float lineSpacingDp = 2f;
        /** 是否设置了 icon */
        private boolean hasIcon = false;

        TagView2(Context context) {
            super(context);
            setPadding(0, dp(paddingDp), 0, dp(paddingDp)); // 上下也加一点内边距

            // 创建 ImageView（初始隐藏）
            imageView = new ImageView(context);
            imageView.setScaleType(ImageView.ScaleType.FIT_CENTER);
            int iconSize = (int) TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP, 11,
                    context.getResources().getDisplayMetrics());
            LayoutParams ivLp = new LayoutParams(iconSize, iconSize);
            addView(imageView, ivLp);
            imageView.setVisibility(GONE);
        }

        /**
         * 应用配置样式（由外部 DayCellViewHolder.applyConfig 调用）
         */
        void applyTagStyle(CalendarViewConfig config) {
            if (config == null) return;
            this.textSizeSp = config.getSecondaryTextSizeSp();
            this.textColor = config.getSecondaryTextColor();
            for (TextView tv : textViews) {
                tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, textSizeSp);
                tv.setTextColor(textColor);
            }
        }

        /**
         * 设置所有文本（清除旧的，但保留 imageView）
         * @param texts 文本列表
         */
        void setTexts(List<String> texts) {
            // 只移除旧的 TextView，保留 imageView
            for (TextView tv : textViews) {
                removeView(tv);
            }
            textViews.clear();

            if (texts == null || texts.isEmpty()) return;

            for (String text : texts) {
                TextView tv = new TextView(getContext());
                tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, textSizeSp);
                tv.setTextColor(textColor);
                tv.setSingleLine(false);      // 支持换行
                tv.setMaxLines(3);
                tv.setEllipsize(android.text.TextUtils.TruncateAt.END);
                tv.setText(text != null ? text : "");

                LayoutParams lp = new LayoutParams(
                        LayoutParams.MATCH_PARENT,
                        LayoutParams.WRAP_CONTENT);
                addView(tv, lp);
                textViews.add(tv);
            }

            requestLayout();
        }

        /**
         * 追加一个文本项
         */
        void addText(String text) {
            TextView tv = new TextView(getContext());
            tv.setTextSize(TypedValue.COMPLEX_UNIT_SP, textSizeSp);
            tv.setTextColor(textColor);
            tv.setSingleLine(false);
            tv.setMaxLines(3);
            tv.setEllipsize(android.text.TextUtils.TruncateAt.END);
            tv.setText(text != null ? text : "");

            LayoutParams lp = new LayoutParams(
                    LayoutParams.MATCH_PARENT,
                    LayoutParams.WRAP_CONTENT);
            addView(tv, lp);
            textViews.add(tv);

            requestLayout();
        }

        @Override
        protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
            int widthLimit = MeasureSpec.getSize(widthMeasureSpec);
            int widthMode = MeasureSpec.getMode(widthMeasureSpec);

            // 如果有 icon，先测量 ImageView（固定尺寸）
            int iconWidth = 0;
            if (hasIcon) {
                measureChild(imageView,
                        MeasureSpec.makeMeasureSpec(imageView.getLayoutParams().width, MeasureSpec.EXACTLY),
                        MeasureSpec.makeMeasureSpec(imageView.getLayoutParams().height, MeasureSpec.EXACTLY));
                iconWidth = imageView.getMeasuredWidth();
            }

            // 普通文本可用宽度：总宽 - 左右padding（占满宽度）
            int normalTextAvailableWidth = widthLimit - dp(paddingDp) * 2;

            // 最后一个文本的可用宽度：如果有 icon 则需要预留空间
            int lastTextAvailableWidth = normalTextAvailableWidth;
            if (hasIcon && !textViews.isEmpty()) {
                lastTextAvailableWidth -= iconWidth + dp(iconTextGapDp) + dp(iconRightMarginDp);
            }

            int totalHeight = getPaddingTop() + getPaddingBottom(); // 上下内边距

            // 测量每个 TextView
            for (int i = 0; i < textViews.size(); i++) {
                TextView child = textViews.get(i);
                // 最后一个文本用缩小后的宽度（给 icon 留空间），其他的用满宽
                boolean isLast = (i == textViews.size() - 1);
                int availableWidth = isLast ? lastTextAvailableWidth : normalTextAvailableWidth;

                measureChild(child,
                        MeasureSpec.makeMeasureSpec(Math.max(availableWidth, dp(40)), MeasureSpec.AT_MOST),
                        MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED));

                totalHeight += child.getMeasuredHeight();

                // 最后一个不加间距
                if (i < textViews.size() - 1) {
                    totalHeight += dp(lineSpacingDp);
                }
            }

            int measuredWidth;
            if (widthMode == MeasureSpec.EXACTLY) {
                measuredWidth = widthLimit;
            } else {
                measuredWidth = widthLimit;
                if (widthMode == MeasureSpec.AT_MOST) {
                    measuredWidth = Math.min(measuredWidth, widthLimit);
                }
            }

            setMeasuredDimension(measuredWidth, totalHeight);

            // 根据高度动态设置圆角背景
            updateRoundedBackground(totalHeight);
        }

        @Override
        protected void onLayout(boolean changed, int l, int t, int r, int b) {
            int containerWidth = r - l;
            int left = dp(paddingDp);
            int top = getPaddingTop();

            // 记录最后一个 TextView 的位置（用于 icon 对齐）
            TextView lastTextView = null;
            int lastTextLeft = 0;
            int lastTextTop = 0;

            for (int i = 0; i < textViews.size(); i++) {
                TextView tv = textViews.get(i);
                layoutChild(tv, left, top);

                // 记录最后一个 TextView
                if (i == textViews.size() - 1) {
                    lastTextView = tv;
                    lastTextLeft = left;
                    lastTextTop = top;
                }

                top += tv.getMeasuredHeight() + dp(lineSpacingDp);
            }

            // 如果有 icon，布局 icon 与最后一个 TextView 的最后一行居中对齐
            if (hasIcon && lastTextView != null) {
                layoutIconAlignedWithLastLine(lastTextView, lastTextTop, containerWidth);
            }
        }

        /**
         * 布局 icon，使其与最后一个 TextView 的最后一行文字垂直居中对齐
         *
         * @param lastTextView 最后一个 TextView
         * @param lastTextTop  最后一个TextView在容器中的top位置
         * @param containerWidth 容器宽度
         */
        private void layoutIconAlignedWithLastLine(TextView lastTextView, int lastTextTop, int containerWidth) {
            // icon 右边距父视图右边 2dp
            int ivRight = containerWidth - dp(iconRightMarginDp);
            int ivLeft = ivRight - imageView.getMeasuredWidth();
            int ivTop;

            int lineCount = lastTextView.getLineCount();
            if (lineCount <= 1) {
                // 单行：与整个 TextView 居中
                ivTop = lastTextTop + (lastTextView.getMeasuredHeight() - imageView.getMeasuredHeight()) / 2;
            } else {
                // 多行：获取最后一行的 bounds，与最后一行居中对齐
                android.graphics.Rect lastLineRect = new android.graphics.Rect();
                lastTextView.getLineBounds(lineCount - 1, lastLineRect);
                // lastLineRect 是相对于 lastTextView 的坐标
                int lastLineCenterY = lastTextTop + lastLineRect.centerY();
                ivTop = lastLineCenterY - imageView.getMeasuredHeight() / 2;
            }

            layoutChild(imageView, ivLeft, ivTop);
        }

        private void layoutChild(View child, int left, int top) {
            child.layout(left, top, left + child.getMeasuredWidth(), top + child.getMeasuredHeight());
        }

        /**
         * 根据高度动态更新圆角矩形背景
         */
        private void updateRoundedBackground(int heightPx) {
            float maxRadiusPx = dp(maxCornerRadiusDp);
            float radius = Math.min(heightPx / 2f, maxRadiusPx);

            android.graphics.drawable.GradientDrawable bg = new android.graphics.drawable.GradientDrawable();
            bg.setColor(backgroundColor);
            bg.setCornerRadii(new float[]{radius, radius, radius, radius, radius, radius, radius, radius});
            setBackground(bg);
        }

        /** 设置背景颜色 */
        void setBackgroundColorValue(int color) {
            this.backgroundColor = color;
            if (getMeasuredHeight() > 0) {
                updateRoundedBackground(getMeasuredHeight());
            }
        }

        /** 设置最大圆角半径(dp) */
        void setMaxCornerRadiusDp(float radiusDp) {
            this.maxCornerRadiusDp = radiusDp;
        }

        /** 设置行间距(dp) */
        void setLineSpacingDp(float spacingDp) {
            this.lineSpacingDp = spacingDp;
        }

        /** 获取当前文本数量 */
        int getTextCount() {
            return textViews.size();
        }

        /**
         * 设置指定位置文本的背景色（调试用）
         */
        void setTextBackgroundColor(int index, int color) {
            if (index >= 0 && index < textViews.size()) {
                textViews.get(index).setBackgroundColor(color);
            }
        }

        /**
         * 设置图标
         * @param drawable 图标 Drawable
         */
        void setTagIcon(Drawable drawable) {
            imageView.setImageDrawable(drawable);
            hasIcon = true;
            imageView.setVisibility(VISIBLE);
            requestLayout();
        }

        /**
         * 设置图标资源 ID
         * @param resId 图标资源 ID
         */
        void setTagIconRes(int resId) {
            imageView.setImageResource(resId);
            hasIcon = true;
            imageView.setVisibility(VISIBLE);
            requestLayout();
        }

        /**
         * 清除图标
         */
        void clearTagIcon() {
            imageView.setImageDrawable(null);
            hasIcon = false;
            imageView.setVisibility(GONE);
            requestLayout();
        }

        private int dp(float value) {
            return (int) TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP, value,
                    getResources().getDisplayMetrics());
        }
    }

    /**
     * 创建一个新的 TagView2 实例（供外部调用）
     */
    TagView2 createTagView2(Context context) {
        return new TagView2(context);
    }
