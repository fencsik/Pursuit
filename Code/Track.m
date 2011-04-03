function Track
    global version = "0.5"
    global TestFlag = 1;
    try
        RunExperiment();
    catch
        ple();
    end_try_catch
    Shutdown();
    clear -global
    clear -all
endfunction

function RunExperiment ()
    Initialize();
    PresentInstructions();
    PresentTask();
    PresentResults();
    DataSummary();
endfunction


######################################################################
### Block-level functions
######################################################################

function PresentInstructions ()
endfunction

function PresentTask ()
    global par
    Rush("MainTaskSequence();", MaxPriority(par.winMain));
endfunction

function MainTaskSequence ()
    ## All functions that need to be run at high priority reside here
    WaitForButtonRelease();
    WaitForSubjectStart();
    MainLoop();
    printf("Running priority = %0.0f\n", Priority());
endfunction

function PresentResults ()
endfunction

function DataSummary ()
    global par
    printf("Tracking duration = %0.2f s\n", par.duration);
    printf("Number of frames  = %0.0f\n", par.nFrames);
    if (any(!isnan(par.frameOnsetTimes)))
        t = par.frameOnsetTimes;
        t = diff(1000 * t(!isnan(t)));
        printf("Frame duration (ms)\n");
        printf("  range = %0.2f - %0.2f\n", min(t), max(t));
        printf("  mean  = %0.2f\n", mean(t));
    endif
    d = sqrt(diff(par.targetX) .^ 2 + diff(par.targetY) .^ 2);
    printf("Target travel distance (pixels)\n");
    printf("  range = %0.4f - %0.4f\n", min(d), max(d));
    printf("  mean  = %0.4f\n", mean(d));
    printf("  sum   = %0.4f\n", sum(d));
    printf("Cursor travel distance (pixels)\n");
    printf("  mean = %0.4f\n", par.travelCursor / par.nFrames);
    printf("   sum = %0.4f\n", par.travelCursor);
    printf("Tracking error (pixels)\n");
    printf("  Mean distance  = %0.4f\n", par.sumDistance / par.nFrames);
    printf("  RMSE           = %0.4f\n", sqrt(par.SSE / par.nFrames));
    printf("Final priority = %0.0f\n", Priority());
endfunction


######################################################################
### Task Control Functions
######################################################################

function WaitForButtonRelease ()
    do 
        [x, y, buttons] = GetMouse();
        keyDown = KbCheck();
        FlipNow();
    until (!(any(buttons) || keyDown))
endfunction

function WaitForSubjectStart ()
    global par
    SetMouse(0, par.centerY);
    tx = par.targetX(1);
    ty = par.targetY(1);
    tLastOnset = FlipNow();
    targNextOnset = tLastOnset + par.frameDuration - par.slackDuration;
    done = 0;
    buttonPressed = 0;
    clickedOnTarget = 0;
    onTarget = 0;
    while (!done)
        [x, y, buttons] = GetMouse();
        ClearScreen();
        DrawTarget(tx, ty, par.colTarget);
        DrawCursor(x, y, par.colCursor);
        Screen("DrawingFinished", par.winMain);
        onTarget = (sqrt((x - tx) ^ 2 + (y - ty) ^ 2) <= par.targetRadius);
        if (!buttonPressed && any(buttons))
            buttonPressed = 1;
        elseif (buttonPressed && !any(buttons))
            if (onTarget)
                done = 1;
            else
                buttonPressed = 0;
            endif
        endif
        tLastOnset = Flip(targNextOnset);
        targNextOnset = tLastOnset + par.frameDuration - par.slackDuration;
    endwhile
    par.targNextOnset = targNextOnset;
    par.lastCursorX = x;
    par.lastCursorY = y;
endfunction

function MainLoop ()
    global par
    frame = 1;
    targNextOnset = par.targNextOnset;
    frameDur = par.frameDuration;
    slackDur = par.slackDuration;
    lastCursorX = par.lastCursorX;
    lastCursorY = par.lastCursorY;
    colTarget = par.colTarget;
    colCursor = par.colCursor;
    pauseFlag = 0;
    while (frame <= par.nFrames)
        [cursorX, cursorY] = GetMouse();
        ClearScreen();
        DrawTarget(par.targetX(frame), par.targetY(frame), colTarget);
        DrawCursor(cursorX, cursorY, colCursor);
        Screen("DrawingFinished", par.winMain);
        tLastOnset = Flip(targNextOnset);
        targNextOnset = tLastOnset + frameDur - slackDur;
        if (KbCheck())
            break;
        endif
        if (!pauseFlag)
            par.frameOnsetTimes(frame) = tLastOnset;
            par.travelCursor += sqrt((cursorX - lastCursorX)^2 +
                                     (cursorY - lastCursorY)^2);
            d = sqrt((cursorX - par.targetX(frame))^2 +
                     (cursorY - par.targetY(frame))^2);
            par.sumDistance += d;
            par.SSE += d^2;
            lastCursorX = cursorX;
            lastCursorY = cursorY;
            frame++;
        endif
    endwhile
endfunction


######################################################################
### Initialization/Shutdown Functions
######################################################################

function Initialize
    InitializePreGraphics();
    InitializeGraphics();
    InitializePostGraphics();
endfunction

function InitializePreGraphics ()
    if (IsMainWindowInitialized())
        error("InitializePreGraphics() called after opening main window");
    endif

    AssertOpenGL();
    more("off"); # avoids confusing among novice users
    KbName("UnifyKeyNames");
    rand("state", 100 * sum(clock));

    global par = struct();
    par.runTime = datestr(now, "mmm dd, yyyy, HH:MM:SS");

    ## Settings
    par.experiment = "PSYC3100-20112";
    par.refreshesPerFrame = 1; # frame rate
    ## target size and motion
    par.targetDiameter = 30; # target size
    par.speedMultiplier = 1.0; # target speed
    par.amplitude = 300;
    par.frequencies = [.07, .15, .23];
    ## cursor size
    par.cursorRadius = 20;
    par.cursorThickness = 2;
    par.logFileName = "TrackLog";

    ## define colors
    par.colBackground = 255;
    par.colText = 0;
    par.colTarget = 100;
    par.colCursor = 0;

    InitializeExperimenterInput();

    ## calculations based on other settings
    par.targetRadius = par.targetDiameter / 2;
    par.dataFileName = sprintf("Data-%s-%s.txt", par.experimenter, 
                               par.experiment);
endfunction

function InitializeExperimenterInput ()
    global par TestFlag
    if (TestFlag)
        par.experimenter = "DEF";
        par.subject = 1;
        par.condition = "test";
        par.duration = 15/60;
    else
        [par.experimenter, par.subject, par.condition, par.duration] = ...
          ExperimenterInput("Experimenter", "", "s", 0,
                            "Subject ID", "", "i", 0,
                            "Condition name", "", "s", 0,
                            "Enter the duration in minutes", "", "f", 0);
    endif
endfunction

function InitializeGraphics
    if (IsMainWindowInitialized())
        error("InitializeGraphics() called with main window already open");
    endif
    global par
    Screen("Preference", "SkipSyncTests", 0);
    Screen("Preference", "VisualDebugLevel", 4);
    screenNumber=max(Screen("Screens"));
    [par.winMain, par.rectMain] = ...
        Screen("OpenWindow", screenNumber, par.colBackground, [], 32, 2);
    Screen(par.winMain, "BlendFunction", ...
           GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    HideCursor();
endfunction

function InitializePostGraphics ()
    if (!IsMainWindowInitialized())
        error("InitializePostGraphics() called without an open window");
    endif

    global par

    ## miscellaneous display settings
    [par.centerX, par.centerY] = RectCenter(par.rectMain);
    par.rectDisplay = ...
      CenterRect((2 * par.amplitude + par.targetRadius) .* [0 0 1 1],
                 par.rectMain);

    ## calculate frame durations and number of frames
    par.refreshDuration = Screen("GetFlipInterval", par.winMain);
    par.frameDuration = par.refreshDuration * par.refreshesPerFrame;
    par.slackDuration = par.refreshDuration / 2.0;

    ## calculate target locations ahead of time
    x = (0:(par.frameDuration):(60 * par.duration)) .* par.speedMultiplier;
    par.nFrames = numel(x);
    par.targetX = par.centerX + SumSine(par.frequencies, par.amplitude, x);
    par.targetY = par.centerY + SumSine(par.frequencies, par.amplitude, x);

    ## initialize variables for storing stats
    par.frameOnsetTimes = nan(par.nFrames, 1);
    par.travelCursor = 0;
    par.sumDistance = 0;
    par.SSE = 0;

    ## define fonts
    if (IsLinux())
        par.textSize = 32;
        par.textFont = Screen("TextFont", par.winMain);
        par.textStyle = 1;
    else
        par.textSize = 18;
        par.textFont = "Arial";
        par.textStyle = Screen("TextStyle", par.winMain);
    endif
    Screen("TextFont", par.winMain, par.textFont);
    Screen("TextSize", par.winMain, par.textSize);
    Screen("TextStyle", par.winMain, par.textStyle);
endfunction

function tf = IsMainWindowInitialized ()
    global par
    tf = exist("par", "var") && isstruct(par) && ...
      isfield(par, "winMain") && ...
      any(par.winMain == Screen("Windows"));
endfunction

function Shutdown ()
    Priority(0);
    fclose("all");
    ShutdownGraphics();
endfunction

function ShutdownGraphics ()
    ShowCursor();
    Screen("CloseAll");
endfunction


######################################################################
### Waveform Management Functions
######################################################################

function w = MakeWaveform (frequency, amplitude)
    ## Returns a waveform structure
    ##
    ## The frequency argument must consist of one or more values, and
    ## the amplitude argument must consist of one value.
    n = numel(frequency);
    w = struct();
    w.frequency = reshape(frequency, n, 1);
    w.amplitude = amplitude(1);
    w.phase = rand(n, 1);
endfunction

function y = CalcWaveform (w, t)
    ## Returns the height of a waveform at time t
    ##
    ## The w argument must be a waveform generated with the MakeWaveform
    ## function, and t must be a single value.
    y = w.amplitude * mean(sin(2 .* pi .* (w.frequency .* t + w.phase)));
endfunction

function height = SumSine (frequencies, amplitude, time)
    ## Generate a sum of sine waves.
    ##
    ## Compute several sine waves with the specifed frequencies and
    ## amplitude, each with a random phase, at the specified times. Then
    ## average them and multiply them by the amplitude.
    ##
    ## A sine wave is sin(2 * pi * (f * x + phi)), where f is the
    ## frequency in Hz, phi is the phase offset, and x is the times, in
    ## seconds, at which the sine wave is sampled.

    ## ensure frequencies are specified as a column vector
    frequencies = reshape(frequencies, numel(frequencies), 1);
    ## ...and time is a row vector
    time = reshape(time, 1, numel(time));

    ## offset in cycles; range = [0, 1)
    phi = rand(size(frequencies));

    ## compute average sine wave
    height = amplitude(1) * ...
      mean(sin(2 .* pi .* (repmat(frequencies, 1, numel(time)) .* ...
                           repmat(time, numel(frequencies), 1) + ...
                           repmat(phi, 1, numel(time)))), 1);
endfunction


######################################################################
### Basic Drawing Routines
######################################################################

function t = Flip (when)
    global par
    Screen("DrawingFinished", par.winMain);
    t = Screen("Flip", par.winMain, when);
endfunction

function t = FlipNow ()
    global par
    Screen("DrawingFinished", par.winMain);
    t = Screen("Flip", par.winMain);
endfunction

function ClearScreen ()
    global par
    Screen("FillRect", par.winMain, par.colBackground);
endfunction

function ClearDisplay ()
    global par
    Screen("FillRect", par.winMain, par.colBackground, par.displayRect);
endfunction

function DrawCursor (x, y, color)
    global par
    Screen("DrawLines", par.winMain, 
           [[x - par.cursorRadius; y], [x + par.cursorRadius; y], ...
            [x; y - par.cursorRadius], [x; y + par.cursorRadius]],
           par.cursorThickness, color);
endfunction

function DrawTarget (x, y, color)
    global par
    Screen("DrawDots", par.winMain, [x; y], par.targetDiameter, color, [], 2);
endfunction


######################################################################
### Functions for collecting input from the user
######################################################################

function varargout = ExperimenterInput (varargin)
    ## Usage:
    ##   ExperimenterInput(Prompt1, Default1, Type1, Confirm1,
    ##                     Prompt2, Default2, Type2, Confirm2, ...)
    n = nargin;
    if nargout ~= n / 4
        error("input and output arguments must match");
    endif
    prompt = varargin(1:4:n);
    defaultValues = varargin(2:4:n);
    inputType = varargin(3:4:n);
    confirmInput = varargin(4:4:n);
    n = numel(prompt);
    varargout = cell(1, nargout);
    for (i = 1:n)
        varargout{i} = GetInput(prompt{i}, defaultValues{i}, inputType{i},
                                confirmInput{i});
    endfor
endfunction

function response = GetInput (prompt, default, inputType, confirm)
    printf("\n");
    switch inputType
        case {"d", "i"}
            response = GetIntegerInput(prompt, default, confirm);
        case "f"
            response = GetFloatInput(prompt, default, confirm);
        case "m"
            response = GetMenuInput(prompt, default, confirm);
        case "s"
            response = GetStringInput(prompt, default, confirm);
        case "v"
            response = GetVectorInput(prompt, default, confirm);
        otherwise
            error("input type %s was not recognized", inputType);
    endswitch
endfunction

function response = GetIntegerInput (prompt, default, confirm)
    do
        response = GetResponse(prompt, default);
        [done, response] = ProcessScalarResponse(response, "i");
        if (done && confirm)
            done = ConfirmResponse(num2str(response));
        endif
    until (done)
endfunction

function response = GetFloatInput (prompt, default, confirm)
    do
        response = GetResponse(prompt, default);
        [done, response] = ProcessScalarResponse(response, "f");
        if (done && confirm)
            done = ConfirmResponse(num2str(response));
        endif
    until (done)
endfunction

function response = GetStringInput (prompt, default, confirm)
    done = 0;
    do
        response = GetResponse(prompt, default);
        done = !isempty(response);
        if (confirm)
            done = ConfirmResponse(response);
        endif
    until (done)
endfunction

function response = GetVectorInput (prompt, default, confirm)
    do
        response = GetResponse(prompt, default);
        [done, response] = ProcessVectorResponse(response, "f");
        if (done && confirm)
            done = ConfirmResponse(num2str(response));
        endif
    until (done)
endfunction

function response = GetMenuInput (prompt, default, confirm)
    oldPagerValue = page_screen_output();
    header = prompt{1};
    menuList = prompt(2:end);
    default;
    i = 0;
    do
        if (mod(i++, 3) == 0)
            PresentMenu(header, menuList);
        endif
        response = GetMenuResponse(default);
        [done, response] = ProcessScalarResponse(response, "i");
        if (done && (response < 1 || response > numel(menuList)))
            done = 0;
        elseif (done && confirm)
            done = ConfirmResponse(num2str(response));
        endif
    until (done)
    page_screen_output(oldPagerValue);
endfunction

function promptOut = SetPrompt (promptIn, default)
    if (!isempty(default))
        df = sprintf(" [%s]", default);
    else
        df = "";
    endif
    promptOut = sprintf("%s%s: ", promptIn, df);
endfunction

function response = GetResponse (prompt, default)
    prompt2 = SetPrompt(prompt, default);
    fflush(stdout);
    response = input(prompt2, "s");
    if (isempty(response) && !isempty(default))
        response = default;
    endif
endfunction

function PresentMenu (header, menuItems)
    printf("%s\n", header);
    for (i = 1:numel(menuItems))
        printf("%-3d-- %s\n", i, menuItems{i});
    endfor
endfunction

function response = GetMenuResponse(default)
    prompt = SetPrompt("Type your selection then press ENTER", default);
    fflush(stdout);
    response = input(prompt, "s");
    if (isempty(response) && !isempty(default))
        response = default;
    endif
endfunction

function [success, responseOut] = ProcessScalarResponse(responseIn, rtype)
    if (isempty(responseIn))
        success = 0;
        responseOut = [];
    elseif (any(rtype == "dif")) % match d/i = integer; f = float
        success = 0;
        [responseOut, n] = sscanf(responseIn, "%f");
        if (n == 1)
            success = 1;
            if (any(rtype == "di"))
                responseOut = fix(responseOut);
            endif
        endif
    else
        success = 1;
        responseOut = responseIn;
    endif
endfunction

function [success, responseOut] = ProcessVectorResponse(responseIn, rtype)
    success = 0;
    responseOut = [];
    if (!isempty(responseIn))
        [responseOut, status] = str2double(responseIn);
        if (all(status == 0) && numel(responseOut) > 0)
            success = 1;
        endif
    endif
endfunction

function confirmed = ConfirmResponse(response)
    printf("You entered \"%s\".\nIs this correct? (y/n) ", response);
    do
        fflush(stdout);
        r = kbhit();
    until (any(r == "yYnN"))
    printf("%s\n", r);
    if (any(r == "yY"))
        confirmed = 1;
    else
        confirmed = 0;
    endif
endfunction

function AbortKeyPressed ()
    global par
    if (!IsMainWindowInitialized())
        return;
    endif
    ClearScreen();
    string = "Are you sure you want to terminate the experiment? (y/n)";
    DrawFormattedText(par.winMain, string, "center", "center",
                      par.colText);
    FlipNow();
    [keyTime, keyCode] = KbPressWait();
    if (keyCode(par.yesKey))
        error("abort key pressed");
    endif
    ClearScreen();
    DrawFormattedText(par.winMain, "Resuming experiment.  Please wait...",
                      "center", "center", par.colText);
    KbReleaseWait();
    t1 = FlipNow();
    ClearScreen();
    t2 = Flip(t1 + 0.993);
    par.targNextOnset = t2 + .233;
endfunction

### Local Variables:
### mode:Octave
### End: