
package com.nativespeed79.badge;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.util.AttributeSet;
import android.util.TypedValue;
import android.view.Gravity;
import android.widget.TextView;

/**
 * BadgeView — 圆形徽章视图
 *
 * 特性：
 *   - 内置 TextView 显示文本内容
 *   - 支持自定义背景色
 *   - 自动以圆形形式展示
 *   - 可调节字号 (sp)，圆的大小会自动跟随字号调整
 *   - 可手动设置圆的直径大小 (dp)
 *   - 文本自动居中
 */
public class BadgeView extends TextView {

    // ====== 默认值 ======

    /** 默认背景色（红色） */
    private static final int DEFAULT_BACKGROUND_COLOR = Color.parseColor("#FF4444");

    /** 默认文字颜色（白色） */
    private static final int DEFAULT_TEXT_COLOR = Color.WHITE;

    /** 默认字号 (sp) */
    private static final float DEFAULT_TEXT_SIZE_SP = 12f;

    /** 默认圆直径 (dp) */
    private static final float DEFAULT_CIRCLE_SIZE_DP = 24f;

    /** 文字内边距 (dp) - 文字与圆边缘的距离 */
    private static final float TEXT_PADDING_DP = 6f;

    // ====== 可配置属性 ======

    /** 背景画笔 */
    private final Paint backgroundPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    /** 背景颜色 */
    private int backgroundColor = DEFAULT_BACKGROUND_COLOR;

    /** 手动设置的圆直径 (像素)，<=0 表示自动根据文字计算 */
    private float manualCircleSizePx = 0f;

    public BadgeView(Context context) {
        this(context, null);
    }

    public BadgeView(Context context, AttributeSet attrs) {
        this(context, attrs, 0);
    }

    public BadgeView(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);

        // 初始化默认配置
        backgroundPaint.setColor(backgroundColor);
        backgroundPaint.setStyle(Paint.Style.FILL);
        backgroundPaint.setAntiAlias(true);

        // 配置 TextView 属性
        setGravity(Gravity.CENTER);
        setTextSize(TypedValue.COMPLEX_UNIT_SP, DEFAULT_TEXT_SIZE_SP);
        setTextColor(DEFAULT_TEXT_COLOR);
        setIncludeFontPadding(false); // 减少字体额外 padding

        // 禁用系统默认背景，我们自己绘制圆形
        setBackground(null);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        float size;

        if (manualCircleSizePx > 0) {
            // 使用手动设置的固定大小
            size = manualCircleSizePx;
        } else {
            // 自动根据文字内容计算圆的大小
            size = calculateAutoCircleSize();
        }

        int finalSize = (int) Math.ceil(size);
        setMeasuredDimension(
                MeasureSpec.makeMeasureSpec(finalSize, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(finalSize, MeasureSpec.EXACTLY)
        );
    }

    /**
     * 根据文字内容自动计算圆的直径
     */
    private float calculateAutoCircleSize() {
        String text = getText().toString();
        if (text == null || text.isEmpty()) {
            return dpToPx(DEFAULT_CIRCLE_SIZE_DP);
        }

        // 测量文字尺寸
        Paint textPaint = getPaint();
        float textWidth = textPaint.measureText(text);
        Paint.FontMetrics fm = textPaint.getFontMetrics();
        float textHeight = fm.descent - fm.ascent;

        // 取宽高的最大值 + 左右/上下各 TEXT_PADDING_DP 的内边距
        float maxTextDimen = Math.max(textWidth, textHeight);
        return maxTextDimen + dpToPx(TEXT_PADDING_DP * 2);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        // 绘制圆形背景
        float cx = getWidth() / 2f;
        float cy = getHeight() / 2f;
        float radius = Math.min(getWidth(), getHeight()) / 2f;

        canvas.drawCircle(cx, cy, radius, backgroundPaint);

        // 绘制文本（调用父类方法）
        super.onDraw(canvas);
    }

    // ==================== 公开 API ====================

    /**
     * 设置背景颜色
     * @param color 颜色值（如 Color.RED 或 Color.parseColor("#FF0000")）
     */
    public void setBadgeBackgroundColor(int color) {
        backgroundColor = color;
        backgroundPaint.setColor(color);
        invalidate();
    }

    /**
     * 设置背景颜色（字符串格式）
     * @param colorStr 颜色字符串（如 "#FF0000"）
     */
    public void setBadgeBackgroundColor(String colorStr) {
        try {
            setBackgroundColor(Color.parseColor(colorStr));
        } catch (IllegalArgumentException e) {
            // 无效颜色字符串，保持原样
            android.util.Log.w("BadgeView", "Invalid color: " + colorStr);
        }
    }

    /**
     * 设置字号（圆的大小会自动跟随调整）
     * @param textSizeSp 字号，单位 sp
     */
    public void setBadgeTextSize(float textSizeSp) {
        setTextSize(TypedValue.COMPLEX_UNIT_SP, textSizeSp);
        requestLayout(); // 触发重新测量以更新圆大小
    }

    /**
     * 设置圆的直径大小（固定值，不再自动跟随字号）
     * @param sizeDp 直径，单位 dp；<=0 恢复为自动模式
     */
    public void setBadgeCircleSize(float sizeDp) {
        if (sizeDp > 0) {
            manualCircleSizePx = dpToPx(sizeDp);
        } else {
            manualCircleSizePx = 0f; // 恢复自动模式
        }
        requestLayout();
        invalidate();
    }

    /**
     * 设置文字颜色
     * @param color 颜色值
     */
    public void setBadgeTextColor(int color) {
        setTextColor(color);
        invalidate();
    }

    /**
     * 获取当前背景颜色
     */
    public int getBadgeBackgroundColor() {
        return backgroundColor;
    }

    /**
     * 获取当前圆直径 (px)
     */
    public float getBadgeCircleSizePx() {
        return manualCircleSizePx > 0 ? manualCircleSizePx : calculateAutoCircleSize();
    }

    /**
     * 获取当前圆直径 (dp)
     */
    public float getBadgeCircleSizeDp() {
        return pxToDp(getBadgeCircleSizePx());
    }

    // ==================== 工具方法 ====================

    /**
     * dp 转 px
     */
    private float dpToPx(float dp) {
        return TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                dp,
                getResources().getDisplayMetrics()
        );
    }

    /**
     * px 转 dp
     */
    private float pxToDp(float px) {
        return px / getResources().getDisplayMetrics().density;
    }
}
