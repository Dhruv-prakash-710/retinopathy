function create_simulink_model()
% CREATE_SIMULINK_MODEL Advanced telemedicine DR screening pipeline model.
%   Models multi-PHC image acquisition, bandwidth constraints, processing
%   queues, quality gate branching, and doctor review capacity with
%   configurable parameters and optimization outputs.
%
%   create_simulink_model()

    disp('═══════════════════════════════════════════════════════════');
    disp('  SIMULINK TELEMEDICINE WORKFLOW MODEL GENERATOR');
    disp('═══════════════════════════════════════════════════════════');

    mdlName = 'DR_Telemedicine_Workflow';

    %% ══════════════════════════════════════════════════════════════
    %  CONFIGURATION PARAMETERS (Editable in MATLAB workspace)
    %% ══════════════════════════════════════════════════════════════
    % Set default parameters in base workspace
    assignin('base', 'NUM_PHCS', 8);
    assignin('base', 'IMAGES_PER_PHC', 50);
    assignin('base', 'AVG_BANDWIDTH_MBPS', 2.0);
    assignin('base', 'IMAGE_SIZE_MB', 5);
    assignin('base', 'GPU_CAPACITY_PER_HOUR', 200);
    assignin('base', 'NUM_DOCTORS', 3);
    assignin('base', 'REVIEW_TIME_SEC', 28);
    assignin('base', 'QUALITY_PASS_RATE', 0.92);
    assignin('base', 'QUALITY_BORDERLINE_RATE', 0.04);
    assignin('base', 'REFERABLE_DR_RATE', 0.18);
    assignin('base', 'OPERATING_HOURS', 8);
    assignin('base', 'SIM_DURATION', 28800);  % 8 hours in seconds

    disp('Parameters set in base workspace. Modify before running.');

    %% ══════════════════════════════════════════════════════════════
    %  CREATE MODEL
    %% ══════════════════════════════════════════════════════════════
    try
        if bdIsLoaded(mdlName)
            close_system(mdlName, 0);
        end
        new_system(mdlName);
    catch
        % System might already exist on disk
        try
            load_system(mdlName);
            close_system(mdlName, 0);
            new_system(mdlName);
        catch
            disp('Creating new model...');
            new_system(mdlName);
        end
    end

    open_system(mdlName);

    %% ══════════════════════════════════════════════════════════════
    %  BLOCK LAYOUT
    %  Multi-stream architecture:
    %    PHC Sources → Network → Quality Gate → {Pass, Borderline, Reject}
    %    Pass → AI Processing → {Referable → Doctor Review, Non-referable → Report}
    %    Borderline → Enhancement → AI Processing
    %    Reject → Recapture Counter
    %% ══════════════════════════════════════════════════════════════

    x = 30; y = 50; w = 80; h = 40; gap = 50;

    %% ── Row 1: Multi-PHC Image Acquisition ──
    add_block('simulink/Sources/Pulse Generator', [mdlName '/PHC_Aggregate_Scans']);
    set_param([mdlName '/PHC_Aggregate_Scans'], ...
        'Period', 'SIM_DURATION / (NUM_PHCS * IMAGES_PER_PHC)', ...
        'PulseWidth', '10', ...
        'Position', num2str([x, y, x+w, y+h]));

    x = x + w + gap;

    %% ── Network Transmission with Bandwidth Constraint ──
    add_block('simulink/Continuous/Transport Delay', [mdlName '/Network_Delay']);
    set_param([mdlName '/Network_Delay'], ...
        'DelayTime', '(IMAGE_SIZE_MB * 8) / AVG_BANDWIDTH_MBPS', ...
        'Position', num2str([x, y, x+w, y+h]));

    x = x + w + gap;

    %% ── Quality Assessment Gate ──
    add_block('simulink/Math Operations/Gain', [mdlName '/Quality_Pass_Filter']);
    set_param([mdlName '/Quality_Pass_Filter'], ...
        'Gain', 'QUALITY_PASS_RATE', ...
        'Position', num2str([x, y, x+w, y+h]));

    x = x + w + gap;

    %% ── AI Processing Queue (Server GPU) ──
    add_block('simulink/Continuous/Transfer Fcn', [mdlName '/GPU_Processing']);
    set_param([mdlName '/GPU_Processing'], ...
        'Numerator', '[1]', ...
        'Denominator', '[12.4 1]', ...
        'Position', num2str([x, y, x+w, y+h]));

    x = x + w + gap;

    %% ── Referable DR Filter ──
    add_block('simulink/Math Operations/Gain', [mdlName '/Referable_Filter']);
    set_param([mdlName '/Referable_Filter'], ...
        'Gain', 'REFERABLE_DR_RATE', ...
        'Position', num2str([x, y, x+w, y+h]));

    x = x + w + gap;

    %% ── Doctor Review Queue ──
    add_block('simulink/Continuous/Transfer Fcn', [mdlName '/Doctor_Review']);
    set_param([mdlName '/Doctor_Review'], ...
        'Numerator', '[1]', ...
        'Denominator', '[REVIEW_TIME_SEC 1]', ...
        'Position', num2str([x, y, x+w, y+h]));

    x = x + w + gap;

    %% ── Output Scopes ──
    % Throughput Monitor
    add_block('simulink/Sinks/Scope', [mdlName '/Throughput_Monitor']);
    set_param([mdlName '/Throughput_Monitor'], ...
        'Position', num2str([x, y, x+60, y+h]));

    % Queue Depth Monitor (separate scope)
    add_block('simulink/Sinks/Scope', [mdlName '/Queue_Monitor']);
    set_param([mdlName '/Queue_Monitor'], ...
        'Position', num2str([x, y+80, x+60, y+80+h]));

    % Rejected images counter
    add_block('simulink/Sinks/To Workspace', [mdlName '/Rejected_Count']);
    set_param([mdlName '/Rejected_Count'], ...
        'VariableName', 'rejected_scans', ...
        'Position', num2str([x, y+160, x+60, y+160+h]));

    %% ── Rejection path ──
    rejX = 30 + 2*(w+gap);
    add_block('simulink/Math Operations/Gain', [mdlName '/Reject_Filter']);
    set_param([mdlName '/Reject_Filter'], ...
        'Gain', '1 - QUALITY_PASS_RATE - QUALITY_BORDERLINE_RATE', ...
        'Position', num2str([rejX, y+160, rejX+w, y+160+h]));

    %% ── Connect Blocks ──
    add_line(mdlName, 'PHC_Aggregate_Scans/1', 'Network_Delay/1', 'autorouting', 'smart');
    add_line(mdlName, 'Network_Delay/1', 'Quality_Pass_Filter/1', 'autorouting', 'smart');
    add_line(mdlName, 'Quality_Pass_Filter/1', 'GPU_Processing/1', 'autorouting', 'smart');
    add_line(mdlName, 'GPU_Processing/1', 'Referable_Filter/1', 'autorouting', 'smart');
    add_line(mdlName, 'Referable_Filter/1', 'Doctor_Review/1', 'autorouting', 'smart');
    add_line(mdlName, 'Doctor_Review/1', 'Throughput_Monitor/1', 'autorouting', 'smart');
    add_line(mdlName, 'GPU_Processing/1', 'Queue_Monitor/1', 'autorouting', 'smart');
    add_line(mdlName, 'Network_Delay/1', 'Reject_Filter/1', 'autorouting', 'smart');
    add_line(mdlName, 'Reject_Filter/1', 'Rejected_Count/1', 'autorouting', 'smart');

    %% ══════════════════════════════════════════════════════════════
    %  SIMULATION SETTINGS
    %% ══════════════════════════════════════════════════════════════
    set_param(mdlName, 'StopTime', 'SIM_DURATION');
    set_param(mdlName, 'SolverType', 'Variable-step');

    %% ══════════════════════════════════════════════════════════════
    %  ANNOTATIONS
    %% ══════════════════════════════════════════════════════════════
    add_block('built-in/Note', [mdlName '/Title']);
    set_param([mdlName '/Title'], ...
        'Position', [30 10 600 25], ...
        'Text', 'DR Telemedicine Screening Pipeline — Resource Allocation Model (RetinaVision v2.4.1)');

    %% ══════════════════════════════════════════════════════════════
    %  SAVE MODEL
    %% ══════════════════════════════════════════════════════════════
    save_system(mdlName);

    disp(['Model "' mdlName '.slx" generated successfully!']);
    disp(' ');
    disp('To run simulation:');
    disp('  1. Modify parameters in workspace (e.g., NUM_PHCS = 10)');
    disp('  2. sim(''DR_Telemedicine_Workflow'')');
    disp('  3. View Throughput_Monitor and Queue_Monitor scopes');
    disp('═══════════════════════════════════════════════════════════');

end
