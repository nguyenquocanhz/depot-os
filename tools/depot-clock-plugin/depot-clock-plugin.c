/* Depot OS — đồng hồ taskbar kiểu Windows cho xfce4-panel (plugin "depot-clock")
 * By WrenEvil.tech & nguyenquocanhz (nqatech)
 *
 * Giờ ở trên, ngày ở dưới (panel thấp thì một dòng). Bấm trái: bật / tắt lịch tháng. Bấm PHẢI: menu của plugin có
 * thêm mục "Điều chỉnh ngày giờ" (mở depot-region), như chuột phải vào đồng hồ của Windows.
 *
 * Vì sao phải viết plugin riêng: đồng hồ có sẵn của xfce4-panel chỉ đăng ký mục "Properties" cho menu chuột phải
 * (xfce_panel_plugin_menu_show_configure) — không có cách nào thêm mục từ bên ngoài, và genmon không nhận chuột phải.
 *
 * Build: scripts/build-clock-plugin.sh (trong chroot Debian 13 của ISO, để khớp đúng thư viện) → file .so được chép
 * vào includes.chroot/usr/lib/x86_64-linux-gnu/xfce4/panel/plugins/libdepot-clock.so và commit kèm mã nguồn này.
 */
#include <gtk/gtk.h>
#include <libxfce4panel/libxfce4panel.h>

#define DATETIME_TOOL "depot-region"

typedef struct {
    XfcePanelPlugin *plugin;
    GtkWidget *button;
    GtkWidget *label;
    GtkWidget *popup;       /* cửa sổ lịch, NULL khi đang đóng */
    guint timer;
} DepotClock;

static gboolean depot_clock_tick(gpointer data);

static void depot_clock_update(DepotClock *dc)
{
    GDateTime *now = g_date_time_new_now_local();
    gchar *time = g_date_time_format(now, "%H:%M");
    gchar *date = g_date_time_format(now, "%d/%m/%Y");
    gchar *tip = g_date_time_format(now, "%A, %-d %B %Y");
    gchar *markup;

    /* panel từ 36 px: hai dòng như Windows; thấp hơn: một dòng */
    if (xfce_panel_plugin_get_size(dc->plugin) >= 36)
        markup = g_strdup_printf("<span size=\"small\">%s\n%s</span>", time, date);
    else
        markup = g_strdup_printf("%s  %s", time, date);
    gtk_label_set_markup(GTK_LABEL(dc->label), markup);
    gtk_widget_set_tooltip_text(dc->button, tip);

    g_free(markup);
    g_free(tip);
    g_free(date);
    g_free(time);
    g_date_time_unref(now);
}

/* hẹn tới đầu phút kế tiếp: không phải thức dậy mỗi giây */
static void depot_clock_schedule(DepotClock *dc)
{
    GDateTime *now = g_date_time_new_now_local();
    guint wait = 60 - (guint) g_date_time_get_second(now);
    g_date_time_unref(now);
    dc->timer = g_timeout_add_seconds(wait > 0 ? wait : 60, depot_clock_tick, dc);
}

static gboolean depot_clock_tick(gpointer data)
{
    DepotClock *dc = data;
    depot_clock_update(dc);
    depot_clock_schedule(dc);
    return G_SOURCE_REMOVE;
}

static void depot_clock_spawn(const gchar *cmd)
{
    GError *err = NULL;
    if (!g_spawn_command_line_async(cmd, &err)) {
        g_warning("depot-clock: không chạy được \"%s\": %s", cmd, err ? err->message : "?");
        g_clear_error(&err);
    }
}

static void depot_clock_open_datetime(GtkWidget *widget, gpointer data)
{
    DepotClock *dc = data;
    if (dc->popup != NULL)
        gtk_widget_destroy(dc->popup);
    depot_clock_spawn(DATETIME_TOOL);
}

static void depot_clock_popup_destroyed(GtkWidget *widget, gpointer data)
{
    ((DepotClock *) data)->popup = NULL;
}

static gboolean depot_clock_popup_focus_out(GtkWidget *widget, GdkEvent *event, gpointer data)
{
    gtk_widget_destroy(widget);
    return FALSE;
}

static gboolean depot_clock_popup_key(GtkWidget *widget, GdkEventKey *event, gpointer data)
{
    if (event->keyval == GDK_KEY_Escape) {
        gtk_widget_destroy(widget);
        return TRUE;
    }
    return FALSE;
}

static void depot_clock_show_calendar(DepotClock *dc)
{
    GtkWidget *win, *box, *head, *cal, *link;
    GDateTime *now;
    gchar *text, *markup;
    gint x = 0, y = 0;

    win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(win), "Lịch");
    gtk_window_set_decorated(GTK_WINDOW(win), FALSE);
    gtk_window_set_resizable(GTK_WINDOW(win), FALSE);
    gtk_window_set_skip_taskbar_hint(GTK_WINDOW(win), TRUE);
    gtk_window_set_skip_pager_hint(GTK_WINDOW(win), TRUE);
    gtk_window_set_keep_above(GTK_WINDOW(win), TRUE);
    gtk_window_set_type_hint(GTK_WINDOW(win), GDK_WINDOW_TYPE_HINT_UTILITY);
    gtk_window_set_screen(GTK_WINDOW(win), gtk_widget_get_screen(dc->button));

    box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_container_set_border_width(GTK_CONTAINER(box), 12);
    gtk_container_add(GTK_CONTAINER(win), box);

    now = g_date_time_new_now_local();
    text = g_date_time_format(now, "%A, %-d %B %Y");
    markup = g_markup_printf_escaped("<b>%s</b>", text);
    head = gtk_label_new(NULL);
    gtk_label_set_markup(GTK_LABEL(head), markup);
    gtk_label_set_xalign(GTK_LABEL(head), 0.0);
    gtk_box_pack_start(GTK_BOX(box), head, FALSE, FALSE, 0);
    g_free(markup);
    g_free(text);
    g_date_time_unref(now);

    cal = gtk_calendar_new();
    gtk_calendar_set_display_options(GTK_CALENDAR(cal),
        GTK_CALENDAR_SHOW_HEADING | GTK_CALENDAR_SHOW_DAY_NAMES | GTK_CALENDAR_SHOW_WEEK_NUMBERS);
    gtk_box_pack_start(GTK_BOX(box), cal, FALSE, FALSE, 0);

    link = gtk_button_new_with_label("Điều chỉnh ngày giờ…");
    gtk_button_set_relief(GTK_BUTTON(link), GTK_RELIEF_NONE);
    gtk_widget_set_halign(link, GTK_ALIGN_END);
    g_signal_connect(link, "clicked", G_CALLBACK(depot_clock_open_datetime), dc);
    gtk_box_pack_start(GTK_BOX(box), link, FALSE, FALSE, 0);

    g_signal_connect(win, "destroy", G_CALLBACK(depot_clock_popup_destroyed), dc);
    g_signal_connect(win, "focus-out-event", G_CALLBACK(depot_clock_popup_focus_out), dc);
    g_signal_connect(win, "key-press-event", G_CALLBACK(depot_clock_popup_key), dc);

    dc->popup = win;
    gtk_widget_show_all(box);
    gtk_widget_realize(win);
    xfce_panel_plugin_position_widget(dc->plugin, win, dc->button, &x, &y);
    gtk_window_move(GTK_WINDOW(win), x, y);
    gtk_widget_show(win);
    gtk_window_present(GTK_WINDOW(win));
}

static gboolean depot_clock_button_press(GtkWidget *widget, GdkEventButton *event, gpointer data)
{
    DepotClock *dc = data;
    if (event->type != GDK_BUTTON_PRESS || event->button != 1)
        return FALSE;       /* chuột phải: để panel mở menu của plugin */
    if (dc->popup != NULL)
        gtk_widget_destroy(dc->popup);
    else
        depot_clock_show_calendar(dc);
    return TRUE;
}

static gboolean depot_clock_size_changed(XfcePanelPlugin *plugin, gint size, gpointer data)
{
    depot_clock_update((DepotClock *) data);
    return TRUE;
}

static void depot_clock_free(XfcePanelPlugin *plugin, gpointer data)
{
    DepotClock *dc = data;
    if (dc->timer != 0)
        g_source_remove(dc->timer);
    if (dc->popup != NULL)
        gtk_widget_destroy(dc->popup);
    g_slice_free(DepotClock, dc);
}

static void depot_clock_construct(XfcePanelPlugin *plugin)
{
    DepotClock *dc = g_slice_new0(DepotClock);
    GtkWidget *item;

    dc->plugin = plugin;
    dc->button = gtk_button_new();
    gtk_button_set_relief(GTK_BUTTON(dc->button), GTK_RELIEF_NONE);
    gtk_widget_set_focus_on_click(dc->button, FALSE);
    dc->label = gtk_label_new(NULL);
    gtk_label_set_justify(GTK_LABEL(dc->label), GTK_JUSTIFY_CENTER);
    gtk_widget_set_margin_start(dc->label, 4);
    gtk_widget_set_margin_end(dc->label, 4);
    gtk_container_add(GTK_CONTAINER(dc->button), dc->label);
    gtk_container_add(GTK_CONTAINER(plugin), dc->button);
    xfce_panel_plugin_add_action_widget(plugin, dc->button);    /* chuột phải lên nút = menu của plugin */
    gtk_widget_show_all(dc->button);

    /* mục thêm vào menu chuột phải, đứng trên các mục Move / Remove / Panel của panel */
    item = gtk_menu_item_new_with_label("Điều chỉnh ngày giờ");
    g_signal_connect(item, "activate", G_CALLBACK(depot_clock_open_datetime), dc);
    gtk_widget_show(item);
    xfce_panel_plugin_menu_insert_item(plugin, GTK_MENU_ITEM(item));

    g_signal_connect(dc->button, "button-press-event", G_CALLBACK(depot_clock_button_press), dc);
    g_signal_connect(plugin, "size-changed", G_CALLBACK(depot_clock_size_changed), dc);
    g_signal_connect(plugin, "free-data", G_CALLBACK(depot_clock_free), dc);

    depot_clock_update(dc);
    depot_clock_schedule(dc);
}

XFCE_PANEL_PLUGIN_REGISTER(depot_clock_construct);
