package gui

import "base:runtime"
import "core:fmt"

import "vendor:glfw"
import gl "vendor:OpenGL"

import im "../../lib/imgui"
import imglfw "../../lib/imgui/backends/glfw"
import imgl "../../lib/imgui/backends/opengl3"

import "../inklib"

glfw_error_callback :: proc "c" (error: i32, description: cstring) {
    context = runtime.default_context()
    fmt.eprintfln("GLFW Error %d: %s", error, description)
}

glfw_wrap :: proc(terminal: ^inklib.Terminal, imgui_func: proc() -> ()) {
    glfw.SetErrorCallback(glfw_error_callback)
    glfw.InitHint(glfw.PLATFORM, glfw.PLATFORM_X11)
    ensure(bool(glfw.Init()))

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_MAJOR)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_MINOR)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    main_scale := imglfw.GetContentScaleForMonitor(glfw.GetPrimaryMonitor())
    window := glfw.CreateWindow(
        i32(WINDOW_WIDTH * main_scale),
        i32(WINDOW_HEIGHT * main_scale),
        "",
        nil, nil)
    ensure(window != nil)
    glfw.MakeContextCurrent(window)
    glfw.SwapInterval(1)
    glfw.SetWindowTitle(window, fmt.caprintf("%s@%s - raycommands", terminal.user, terminal.host))

    gl.load_up_to(GL_MAJOR, GL_MINOR, glfw.gl_set_proc_address)

    im.CHECKVERSION()
    im.CreateContext()
    io := im.GetIO()
    io.ConfigFlags |= {
        .NavEnableKeyboard,
    }

    font_path :: "resources/regular.ttf"

    font := im.FontAtlas_AddFontFromFileTTF(
        io.Fonts,
        font_path,
        12.0 * main_scale,
        nil,
        &cyrillic_ranges[0],
    )

    if font == nil {
        fmt.eprintfln("Unable to load font: %s", font_path)
    }

    im.StyleColorsDark()

    style := im.GetStyle()
    im.Style_ScaleAllSizes(style, main_scale)
    style.FontScaleDpi = main_scale
    io.ConfigDpiScaleFonts = true
    io.ConfigDpiScaleViewports = true
    io.IniFilename = nil

    imglfw.InitForOpenGL(window, true)
    imgl.Init(GLSL_VERSION)

    clear_color := im.Vec4{0.0, 0.0, 0.0, 1.0}
    gl.ClearColor(
        clear_color.x * clear_color.w,
        clear_color.y * clear_color.w,
        clear_color.z * clear_color.w,
        clear_color.w
    )

    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()

        if glfw.GetWindowAttrib(window, glfw.ICONIFIED) != 0 {
            imglfw.Sleep(10)
            continue
        }

        imgl.NewFrame()
        imglfw.NewFrame()
        im.NewFrame()

        imgui_func()

        im.Render()
        display_w, display_h := glfw.GetFramebufferSize(window)
        gl.Viewport(0, 0, display_w, display_h)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        imgl.RenderDrawData(im.GetDrawData())
        glfw.SwapBuffers(window)
        free_all(context.temp_allocator)
    }

    imgl.Shutdown()
    imglfw.Shutdown()
    im.DestroyContext()

    glfw.DestroyWindow(window)
    glfw.Terminate()
}