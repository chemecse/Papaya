#pragma once

#include "papaya_platform.h"
#include "libs/gl.h"
#include "libs/timer.h"

#include "core/crop_rotate.h"
#include "core/picker.h"
#include "core/prefs.h"

struct ImDrawData;

enum PapayaTex_ {
    PapayaTex_Font,
    PapayaTex_UI,
    PapayaTex_COUNT
};

enum PapayaCol_ {
    PapayaCol_Clear,
    PapayaCol_Workspace,
    PapayaCol_Button,
    PapayaCol_ButtonHover,
    PapayaCol_ButtonActive,
    PapayaCol_AlphaGrid1,
    PapayaCol_AlphaGrid2,
    PapayaCol_ImageSizePreview1,
    PapayaCol_ImageSizePreview2,
    PapayaCol_Transparent,
    PapayaCol_COUNT
};

enum PapayaMesh_ {
    PapayaMesh_ImGui,
    PapayaMesh_Canvas,
    PapayaMesh_ImageSizePreview,
    PapayaMesh_AlphaGrid,
    PapayaMesh_BrushCursor,
    PapayaMesh_EyeDropperCursor,
    PapayaMesh_CropOutline,
    PapayaMesh_PickerHStrip,
    PapayaMesh_PickerSVBox,
    PapayaMesh_RTTBrush,
    PapayaMesh_RTTAdd,
    PapayaMesh_COUNT
};

enum PapayaShader_ {
    PapayaShader_ImGui,
    PapayaShader_VertexColor,
    PapayaShader_ImageSizePreview,
    PapayaShader_Brush,
    PapayaShader_BrushCursor,
    PapayaShader_EyeDropperCursor,
    PapayaShader_PickerHStrip,
    PapayaShader_PickerSVBox,
    PapayaShader_AlphaGrid,
    PapayaShader_PreMultiplyAlpha,
    PapayaShader_DeMultiplyAlpha,
    PapayaShader_COUNT
};

enum PapayaUndoOp_ {
    PapayaUndoOp_Brush,
    PapayaUndoOp_COUNT
};

enum PapayaTool_ {
    PapayaTool_None,
    PapayaTool_Brush,
    PapayaTool_EyeDropper,
    PapayaTool_CropRotate,
    PapayaTool_COUNT
};

struct SystemInfo{
    int32 gl_version[2];
};

struct Layout {
    int32 width, height;
    uint32 menu_horizontal_offset, title_bar_buttons_width, title_bar_height;
    float proj_mtx[4][4];
};

// =======================================================================================
// Undo structs
struct UndoData {
    // TODO: Convert into a union of structs once multiple types of undo ops are required
    uint8 op_code; // Stores enum of type PapayaUndoOp_
    UndoData* prev, *next;
    Vec2i pos, size; // Position and size of the suffixed data block
    bool IsSubRect; // If true, then the suffixed image data contains two subrects - before and after the brush
    Vec2 line_segment_start_uv;
    // Image data goes after this
};

struct UndoBuffer {
    void* start;   // Pointer to beginning of undo buffer memory block // TODO: Change pointer types to int8*?
    void* top;     // Pointer to the top of the undo stack
    UndoData* base;    // Pointer to the base of the undo stack
    UndoData* current; // Pointer to the current location in the undo stack. Goes back and forth during undo-redo.
    UndoData* last;    // Last undo data block in the buffer. Should be located just before Top.
    size_t size;  // Size of the undo buffer in bytes
    size_t count;  // Number of undo ops in buffer
    size_t current_index; // Index of the current undo data block from the beginning
};

// =======================================================================================

struct Document {
    int32 width, height;
    int32 components_per_pixel;
    uint32 texture_id;
    Vec2i canvas_pos;
    float canvas_zoom;
    float inverse_aspect;
    float proj_mtx[4][4];
    UndoBuffer undo;
};

struct Mouse {
    Vec2i pos;
    Vec2i last_pos;
    Vec2 uv;
    Vec2 last_uv;
    bool is_down[3];
    bool was_down[3];
    bool pressed[3];
    bool released[3];
    bool in_workspace;
};

struct Tablet {
    Vec2i pos;
    float pressure;
};

struct Brush {
    int32 diameter;
    int32 max_diameter;
    float opacity; // Range: [0.0, 1.0]
    float hardness; // Range: [0.0, 1.0]
    bool anti_alias;

    Vec2i paint_area_1, paint_area_2;

    // TODO: Move some of this stuff to the Mouse struct?
    Vec2i rt_drag_start_pos;
    bool rt_drag_with_shift;
    int32 rt_drag_start_diameter;
    float rt_drag_start_hardness, rt_drag_start_opacity;
    bool draw_line_segment;
    Vec2 line_segment_start_uv;
    bool being_dragged;
    bool is_straight_drag;
    bool was_straight_drag;
    bool straight_drag_snap_x;
    bool straight_drag_snap_y;
    Vec2 straight_drag_start_uv;
};

struct EyeDropper {
    Color color;
};

struct Profile {
    int64 current_time; // Used on Windows.
    float last_frame_time; // Used on Linux. TODO: Combine this var and the one above.
    Timer timers[Timer_COUNT];
};

struct Misc {
    // TODO: This entire struct is for stuff to be refactored at some point
    uint32 fbo;
    uint32 fbo_render_tex, fbo_sample_tex;
    bool draw_overlay;
    bool show_metrics;
    bool show_undo_buffer;
    bool menu_open;
    bool prefs_open;
    bool preview_image_size;
};

struct PapayaMemory {
    bool is_running;
    SystemInfo system;
    Layout window;
    Document doc;
    Mouse mouse;
    Tablet tablet;
    Profile profile;

    uint32 textures[PapayaTex_COUNT];
    Color colors[PapayaCol_COUNT];
    Mesh meshes[PapayaMesh_COUNT];
    Shader shaders[PapayaShader_COUNT];

    PapayaTool_ current_tool;
    Brush brush;
    EyeDropper eye_dropper;
    Picker picker;
    CropRotate crop_rotate;
    Misc misc;
};

namespace core {
    void init(PapayaMemory* Mem);
    void destroy(PapayaMemory* Mem);
    void resize(PapayaMemory* Mem, int32 Width, int32 Height);
    void update(PapayaMemory* Mem);
    void render_imgui(ImDrawData* DrawData, void* MemPtr);
    bool open_doc(char* Path, PapayaMemory* Mem);
    void close_doc(PapayaMemory* Mem);
    void resize_doc(PapayaMemory* Mem, int32 Width, int32 Height);
}
