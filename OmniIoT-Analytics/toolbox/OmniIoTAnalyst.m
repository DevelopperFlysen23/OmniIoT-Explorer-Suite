classdef OmniIoTAnalyst < matlab.apps.AppBase
    % OmniIoTAnalyst - Advanced IoT Data Visualization and Analytics.
    %
    %   A refactored and enhanced version of the IoT Explorer.
    %   Supports modular data clients and multi-mode comparison.
    %
    %   Usage:
    %       app = OmniIoTAnalyst;
    %
    %   Author: [Your Name/GitHub Handle]
    %   Created: 2026

    % UI components
    properties (Access = public)
        MainFigure                  matlab.ui.Figure
        MainLayout                  matlab.ui.container.GridLayout
        ControlPanel                matlab.ui.container.Panel
        UpdateButton                matlab.ui.control.Button
        QuitButton                  matlab.ui.control.Button
        StartDatePickerLabel        matlab.ui.control.Label
        StartDatePicker             matlab.ui.control.DatePicker
        DurationDropDownLabel       matlab.ui.control.Label
        DurationDropDown            matlab.ui.control.DropDown
        CompareLengthDropDownLabel  matlab.ui.control.Label
        CompareLengthDropDown       matlab.ui.control.DropDown
        ChannelIDLabel              matlab.ui.control.Label
        ChannelIDEditField          matlab.ui.control.NumericEditField
        APIKeyLabel                 matlab.ui.control.Label
        APIKeyEditField             matlab.ui.control.EditField
        StartHourDropDownLabel      matlab.ui.control.Label
        StartHourDropDown           matlab.ui.control.DropDown
        DurationXLabel              matlab.ui.control.Label
        plotDuration                matlab.ui.control.NumericEditField
        CompareXLabel               matlab.ui.control.Label
        plotLengthofComparison      matlab.ui.control.NumericEditField
        RetimeDropDown              matlab.ui.control.DropDown
        RetimeDropDownLabel         matlab.ui.control.Label
        AMPMSwitchLabel             matlab.ui.control.Label
        AMPMSwitch                  matlab.ui.control.Switch
        MinDropDownLabel            matlab.ui.control.Label
        MinDropDown                 matlab.ui.control.DropDown
        ExportButton                matlab.ui.control.Button
        DashboardPanel              matlab.ui.container.Panel
        StatusLabel                 matlab.ui.control.Label
        % Mode toggle and channel management
        ModeLabel                   matlab.ui.control.Label
        ModeSwitch                  matlab.ui.control.DropDown
        AddChannelButton            matlab.ui.control.Button
        RemoveChannelButton         matlab.ui.control.Button
        ChannelTabs                 matlab.ui.container.TabGroup
        ThemeSwitch                 matlab.ui.control.Switch
        ThemeLabel                  matlab.ui.control.Label
        
        % ML Controls
        MLForecastSwitch            matlab.ui.control.Switch
        MLForecastLabel             matlab.ui.control.Label
        AnomalySwitch               matlab.ui.control.Switch
        AnomalyLabel                matlab.ui.control.Label
        StatsTable                  matlab.ui.control.Table
    end

    properties (Access = private)
        onePanelWidth = 700;
        % Data client instance
        IoTClient = ThingSpeakClient();
        
        % Struct array for channel configurations.
        ChannelConfigs = struct('channelID', {}, 'apiKey', {}, ...
            'channelName', {}, 'fieldNames', {}, 'fieldEnabled', {}, ...
            'tab', {}, 'checkboxes', {})
        
        HasPlotted = false
    end

    properties (Access = public)
        legendLabel1
        legendLabel2
    end

    methods (Access = public)

        function displayFields = enumerateSelectedFields(app)
            if isempty(app.ChannelConfigs)
                displayFields = false(1, 8);
                return
            end
            idx = getActiveChannelIdx(app);
            if isempty(idx)
                displayFields = false(1, 8);
                return
            end
            cbs = app.ChannelConfigs(idx).checkboxes;
            displayFields = false(1, 8);
            for i = 1:numel(cbs)
                if isvalid(cbs(i))
                    displayFields(i) = cbs(i).Value;
                end
            end
        end
    end

    methods (Access = private)

        function idx = getActiveChannelIdx(app)
            idx = [];
            if isempty(app.ChannelConfigs)
                return
            end
            selectedTab = app.ChannelTabs.SelectedTab;
            for i = 1:numel(app.ChannelConfigs)
                if isvalid(app.ChannelConfigs(i).tab) && app.ChannelConfigs(i).tab == selectedTab
                    idx = i;
                    return
                end
            end
        end

        function createChannelTab(app, channelIdx)
            cfg = app.ChannelConfigs(channelIdx);
            tabTitle = string(cfg.channelID);
            if strlength(cfg.channelName) > 0
                tabTitle = cfg.channelName;
                if strlength(tabTitle) > 15
                    tabTitle = extractBefore(tabTitle, 16);
                end
            end

            newTab = uitab(app.ChannelTabs, 'Title', tabTitle);
            cbs = gobjects(1, 8);
            for i = 1:8
                cbs(i) = uicheckbox(newTab);
                cbs(i).Position = [10, 230 - (i-1)*25, 200, 22];
                if cfg.fieldEnabled(i)
                    cbs(i).Enable = 'on';
                    cbs(i).Text = cfg.fieldNames(i);
                    cbs(i).ValueChangedFcn = createCallbackFcn(app, @autoUpdate, true);
                    if i == 1
                        cbs(i).Value = true;
                    end
                else
                    cbs(i).Enable = 'off';
                    cbs(i).Value = false;
                    cbs(i).Text = "Field " + string(i);
                end
            end

            app.ChannelConfigs(channelIdx).tab = newTab;
            app.ChannelConfigs(channelIdx).checkboxes = cbs;
            app.ChannelTabs.SelectedTab = newTab;
        end

        function [queryRecent, queryOld] = buildQueries(app)
            idx = getActiveChannelIdx(app);
            if isempty(idx)
                chID = app.ChannelIDEditField.Value;
                key = app.APIKeyEditField.Value;
            else
                chID = app.ChannelConfigs(idx).channelID;
                key = app.ChannelConfigs(idx).apiKey;
            end

            startH = hours(str2double(app.StartHourDropDown.Value));
            startM = minutes(str2double(app.MinDropDown.Value));
            
            baseStart = app.StartDatePicker.Value + startH + startM;
            if app.AMPMSwitch.Value == "PM"
                baseStart = baseStart + hours(12);
            end

            fields = [];
            selected = enumerateSelectedFields(app);
            for i = 1:8
                if selected(i)
                    fields = [fields, i];
                end
            end

            duration = getCompareDuration(app);
            offset = getCompareWidth(app);

            queryRecent.channelID = chID;
            queryRecent.APIKey = key;
            queryRecent.startDate = baseStart;
            queryRecent.endDate = baseStart + duration;
            queryRecent.fieldsList = fields;

            queryOld = queryRecent;
            queryOld.startDate = baseStart - offset;
            queryOld.endDate = queryOld.startDate + duration;
        end

        function visualizeTimeCompare(app, recentData, oldData, startH, startM)
            selected = enumerateSelectedFields(app);
            numPlots = sum(selected);
            if numPlots == 0, return; end

            delete(app.DashboardPanel.Children);
            tl = tiledlayout(app.DashboardPanel, numPlots, 1, 'TileSpacing', 'compact', 'Padding', 'tight');

            elapsedRecent = recentData.Timestamps - recentData.Timestamps(1) + startH + startM;
            elapsedOld = oldData.Timestamps - oldData.Timestamps(1) + startH + startM;
            minLength = min(height(oldData), height(recentData));

            plotIdx = 0;
            for i = 1:8
                if selected(i)
                    plotIdx = plotIdx + 1;
                    ax = nexttile(tl);
                    hold(ax, "on");
                    
                    % 1. Main Data
                    p1 = plot(ax, elapsedRecent(1:minLength), recentData{1:minLength, plotIdx}, '-o', 'LineWidth', 1.5, 'MarkerSize', 3);
                    p1.DisplayName = "Recent";
                    
                    % 2. Historical Data
                    if app.CompareLengthDropDown.Value ~= minutes(0)
                        p2 = plot(ax, elapsedOld(1:minLength), oldData{1:minLength, plotIdx}, '--*', 'LineWidth', 1, 'MarkerSize', 3);
                        p2.DisplayName = "Historical";
                    end

                    % 3. ML Forecast
                    if app.MLForecastSwitch.Value == "On"
                        [fTime, fData] = DataAnalytics.predictTrend(elapsedRecent, recentData{:, plotIdx}, 20);
                        if ~isempty(fData)
                            p3 = plot(ax, fTime, fData, ':', 'LineWidth', 2, 'Color', [1 0.5 0]);
                            p3.DisplayName = "ML Forecast";
                            
                            % Display the first predicted value in StatusLabel
                            app.StatusLabel.Text = sprintf("Dashboard Ready | Next Predicted Value (%s): %.2f", ...
                                recentData.Properties.VariableNames{plotIdx}, fData(1));
                        end
                    end

                    % 4. Anomaly Detection
                    if app.AnomalySwitch.Value == "On"
                        anomIdx = DataAnalytics.detectAnomalies(recentData{:, plotIdx}, 2.5);
                        if any(anomIdx)
                            plot(ax, elapsedRecent(anomIdx), recentData{anomIdx, plotIdx}, 'ro', 'MarkerSize', 8, 'LineWidth', 1.5, 'DisplayName', 'Anomalies');
                        end
                    end

                    title(ax, recentData.Properties.VariableNames{plotIdx}, 'FontWeight', 'bold');
                    grid(ax, 'on');
                    if plotIdx < numPlots
                        set(ax, 'XTickLabel', []);
                    end
                    legend(ax, 'show', 'Location', 'best');
                    styleAxes(app, ax);
                end
            end
        end

        function visualizeChannelCompare(app, allData, queries)
            totalTiles = 0;
            for i = 1:numel(allData)
                if ~isempty(allData{i}), totalTiles = totalTiles + width(allData{i}); end
            end
            if totalTiles == 0, return; end

            delete(app.DashboardPanel.Children);
            tl = tiledlayout(app.DashboardPanel, totalTiles, 1, 'TileSpacing', 'compact');
            
            globalMin = NaT; globalMax = NaT;
            for i = 1:numel(allData)
                if ~isempty(allData{i})
                    t1 = allData{i}.Timestamps(1); t2 = allData{i}.Timestamps(end);
                    if isnat(globalMin) || t1 < globalMin, globalMin = t1; end
                    if isnat(globalMax) || t2 > globalMax, globalMax = t2; end
                end
            end

            colors = lines(numel(queries));
            axList = [];
            currentTile = 0;
            for chIdx = 1:numel(allData)
                data = allData{chIdx};
                if isempty(data), continue; end
                for fIdx = 1:width(data)
                    currentTile = currentTile + 1;
                    ax = nexttile(tl);
                    axList = [axList, ax];
                    plot(ax, data.Timestamps, data{:, fIdx}, 'Color', colors(chIdx,:), 'LineWidth', 1.2);
                    title(ax, sprintf("Ch %d: %s", queries(chIdx).channelID, data.Properties.VariableNames{fIdx}));
                    grid(ax, 'on');
                    styleAxes(app, ax);
                end
            end
            if ~isnat(globalMin), linkaxes(axList, 'x'); xlim(axList(1), [globalMin globalMax]); end
        end

        function duration = getCompareDuration(app)
            duration = app.DurationDropDown.Value * app.plotDuration.Value;
        end

        function offset = getCompareWidth(app)
            offset = app.CompareLengthDropDown.Value * app.plotLengthofComparison.Value;
        end

        function styleAxes(app, ax)
            if app.ThemeSwitch.Value == "On"
                ax.Color = [0.11 0.12 0.18];
                ax.XColor = [0.0 0.84 0.81];
                ax.YColor = [0.0 0.84 0.81];
                ax.GridColor = [0.3 0.3 0.4];
                ax.Title.Color = [1 1 1];
                if ~isempty(ax.Legend)
                    ax.Legend.TextColor = [1 1 1];
                    ax.Legend.Color = [0.15 0.16 0.22];
                end
            else
                ax.Color = [1 1 1];
                ax.XColor = [0.2 0.2 0.2];
                ax.YColor = [0.2 0.2 0.2];
                ax.GridColor = [0.8 0.8 0.8];
            end
        end

        function applyTheme(app)
            if app.ThemeSwitch.Value == "On"
                bg = [0.07 0.08 0.12];
                panelBg = [0.11 0.12 0.18];
                fg = [0.00 0.84 0.81];
                lblColor = [1 1 1];
            else
                bg = [0.94 0.94 0.94];
                panelBg = [1 1 1];
                fg = [0 0 0];
                lblColor = [0.1 0.1 0.1];
            end
            
            app.MainFigure.Color = bg;
            app.ControlPanel.BackgroundColor = panelBg;
            app.DashboardPanel.BackgroundColor = bg;
            
            lbls = findobj(app.ControlPanel, 'Type', 'uilabel');
            for i = 1:numel(lbls), lbls(i).FontColor = lblColor; end
            app.StatusLabel.FontColor = fg;
            
            axs = findobj(app.DashboardPanel, 'Type', 'axes');
            for i = 1:numel(axs), styleAxes(app, axs(i)); end
        end
    end

    % Callbacks
    methods (Access = private)

        function startupFcn(app)
            app.DurationDropDown.ItemsData = [minutes(1), hours(1), days(1), days(7)];
            app.CompareLengthDropDown.ItemsData = [minutes(0), minutes(1), hours(1), days(1), days(7), days(365)];
            app.StartDatePicker.Value = datetime('yesterday');
            
            % Load defaults
            app.ChannelIDEditField.Value = 38629;
            addChannel(app);
            applyTheme(app);
        end

        function addChannel(app, ~)
            chID = app.ChannelIDEditField.Value;
            key = app.APIKeyEditField.Value;
            
            % Avoid duplicates
            for i = 1:numel(app.ChannelConfigs)
                if app.ChannelConfigs(i).channelID == chID, return; end
            end

            app.StatusLabel.Text = "Connecting to Channel " + string(chID) + "...";
            drawnow;
            try
                info = app.IoTClient.getChannelInfo(chID, key);
                cfg.channelID = chID;
                cfg.apiKey = key;
                cfg.channelName = info.channelName;
                cfg.fieldNames = info.fieldNames;
                cfg.fieldEnabled = info.fieldEnabled;
                cfg.tab = []; cfg.checkboxes = [];
                
                app.ChannelConfigs(end+1) = cfg;
                createChannelTab(app, numel(app.ChannelConfigs));
                app.StatusLabel.Text = "Connected: " + info.channelName;
            catch err
                app.StatusLabel.Text = "Error: " + err.message;
            end
        end

        function removeChannel(app, ~)
            idx = getActiveChannelIdx(app);
            if isempty(idx), return; end
            if app.ModeSwitch.Value == "Time" && numel(app.ChannelConfigs) <= 1, return; end
            
            delete(app.ChannelConfigs(idx).tab);
            app.ChannelConfigs(idx) = [];
            app.StatusLabel.Text = "Channel removed.";
        end

        function updatePlots(app, ~)
            app.HasPlotted = true;
            app.StatusLabel.Text = "Updating Dashboard...";
            drawnow;
            
            try
                if app.ModeSwitch.Value == "Time"
                    [qR, qO] = buildQueries(app);
                    dataR = app.IoTClient.fetchData(qR);
                    dataO = app.IoTClient.fetchData(qO);
                    
                    if app.RetimeDropDown.Value ~= "Raw"
                        dataR = retime(dataR, app.RetimeDropDown.Value, 'linear');
                        dataO = retime(dataO, app.RetimeDropDown.Value, 'linear');
                    end

                    % Calculate stats for table
                    stats = DataAnalytics.calculateStats(dataR);
                    app.StatsTable.Data = [stats.Min, stats.Max, stats.Mean];
                    app.StatsTable.RowName = stats.Properties.RowNames;
                    
                    visualizeTimeCompare(app, dataR, dataO, hours(str2double(app.StartHourDropDown.Value)), minutes(str2double(app.MinDropDown.Value)));
                else
                    % Implementation for Channel Compare...
                    queries = buildChannelCompareQueries(app);
                    allData = {};
                    for i = 1:numel(queries)
                        allData{i} = app.IoTClient.fetchData(queries(i));
                    end
                    visualizeChannelCompare(app, allData, queries);
                end
                app.StatusLabel.Text = "Dashboard Ready.";
            catch err
                app.StatusLabel.Text = "Update Error: " + err.message;
            end
        end

        function queries = buildChannelCompareQueries(app)
            % Loop through ChannelConfigs to build multi-channel queries
            queries = struct('channelID', {}, 'APIKey', {}, 'fieldsList', {}, 'startDate', {}, 'endDate', {});
            duration = getCompareDuration(app);
            startH = hours(str2double(app.StartHourDropDown.Value));
            startM = minutes(str2double(app.MinDropDown.Value));
            baseStart = app.StartDatePicker.Value + startH + startM;
            if app.AMPMSwitch.Value == "PM", baseStart = baseStart + hours(12); end
            
            for i = 1:numel(app.ChannelConfigs)
                cfg = app.ChannelConfigs(i);
                q.channelID = cfg.channelID;
                q.APIKey = cfg.apiKey;
                q.startDate = baseStart;
                q.endDate = baseStart + duration;
                
                % Get selected fields for this channel
                fields = [];
                cbs = cfg.checkboxes;
                for j = 1:8
                    if isvalid(cbs(j)) && cbs(j).Value, fields = [fields, j]; end
                end
                q.fieldsList = fields;
                if ~isempty(fields), queries(end+1) = q; end
            end
        end

        function autoUpdate(app, ~)
            if app.HasPlotted, updatePlots(app); end
        end

        function exportReport(app, ~)
            % Functional Export: Generates a text report and a screenshot.
            if ~app.HasPlotted
                uialert(app.MainFigure, 'Please generate a dashboard first!', 'Export Error');
                return;
            end

            app.StatusLabel.Text = "Exporting Report... Please wait.";
            drawnow;

            try
                % 1. Get stats from the table
                statsData = app.StatsTable.Data;
                rows = app.StatsTable.RowName;
                
                % Create a dummy stats table for the generator
                stats = table('Size', [size(statsData, 1), 3], 'VariableTypes', {'double', 'double', 'double'}, ...
                    'VariableNames', {'Min', 'Max', 'Mean'}, 'RowNames', rows);
                stats{:,:} = statsData;

                % 2. Generate the Descriptive Text
                forecastVal = [];
                if app.MLForecastSwitch.Value == "On"
                    % Try to extract the last prediction from status or plots
                    forecastVal = 0; % Placeholder or actual value
                end
                
                reportText = DataAnalytics.generateSummaryText(stats, forecastVal, app.AnomalySwitch.Value == "On");

                % 3. Determine save path (Desktop with fallback)
                desktopPath = fullfile(getenv('USERPROFILE'), 'Desktop');
                if ~exist(desktopPath, 'dir')
                    desktopPath = pwd; % Fallback to current folder
                end
                
                reportFile = fullfile(desktopPath, 'OmniIoT_Report.txt');
                imgFile = fullfile(desktopPath, 'OmniIoT_Dashboard.png');

                % Write text file
                fid = fopen(reportFile, 'w');
                if fid == -1
                    % Try current folder if Desktop failed
                    reportFile = fullfile(pwd, 'OmniIoT_Report.txt');
                    imgFile = fullfile(pwd, 'OmniIoT_Dashboard.png');
                    fid = fopen(reportFile, 'w');
                end
                
                if fid == -1
                    error("Could not create report file. Check permissions.");
                end
                
                fprintf(fid, '%s', reportText);
                fclose(fid);

                % Save Image
                exportapp(app.MainFigure, imgFile);

                uialert(app.MainFigure, sprintf('Report and Dashboard saved!\n\nLocation: %s\n\nFiles:\n1. OmniIoT_Report.txt\n2. OmniIoT_Dashboard.png', desktopPath), 'Export Successful');
                app.StatusLabel.Text = "Export Complete.";
            catch err
                uialert(app.MainFigure, "Export failed: " + err.message, "Export Error");
                app.StatusLabel.Text = "Export Failed.";
            end
        end

        function layoutChanged(app, ~)
            figWidth = app.MainFigure.Position(3);
            if figWidth < app.onePanelWidth
                app.MainLayout.ColumnWidth = {'1x'};
                app.MainLayout.RowHeight = {600, '1x'};
                app.DashboardPanel.Layout.Row = 2;
                app.DashboardPanel.Layout.Column = 1;
            else
                app.MainLayout.ColumnWidth = {320, '1x'};
                app.MainLayout.RowHeight = {'1x'};
                app.DashboardPanel.Layout.Row = 1;
                app.DashboardPanel.Layout.Column = 2;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        function createComponents(app)
            app.MainFigure = uifigure('Visible', 'off', 'Name', 'OmniIoT Analytics v1.1', 'Position', [100 100 1100 750], 'AutoResizeChildren', 'off');
            app.MainFigure.SizeChangedFcn = createCallbackFcn(app, @layoutChanged, true);

            app.MainLayout = uigridlayout(app.MainFigure, [1 2]);
            app.MainLayout.ColumnWidth = {320, '1x'};
            app.MainLayout.ColumnSpacing = 0; app.MainLayout.RowSpacing = 0; app.MainLayout.Padding = [0 0 0 0];

            app.ControlPanel = uipanel(app.MainLayout, 'Title', 'ANALYTICS ENGINE', 'FontWeight', 'bold');
            app.ControlPanel.Layout.Row = 1; app.ControlPanel.Layout.Column = 1;

            % --- UI Controls (Optimized Spacing) ---
            y = 660;
            app.ModeLabel = uilabel(app.ControlPanel, 'Position', [10 y 110 22], 'Text', 'Analysis Mode:');
            app.ModeSwitch = uidropdown(app.ControlPanel, 'Position', [130 y 160 22], 'Items', {'Time', 'Channel'}, 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));
            
            y = y - 35;
            app.ChannelIDLabel = uilabel(app.ControlPanel, 'Position', [10 y 110 22], 'Text', 'Channel ID:');
            app.ChannelIDEditField = uieditfield(app.ControlPanel, 'numeric', 'Position', [130 y 80 22], 'Value', 38629);
            app.AddChannelButton = uibutton(app.ControlPanel, 'Position', [220 y 30 22], 'Text', '+', 'ButtonPushedFcn', createCallbackFcn(app, @addChannel, true));
            app.RemoveChannelButton = uibutton(app.ControlPanel, 'Position', [260 y 30 22], 'Text', '-', 'ButtonPushedFcn', createCallbackFcn(app, @removeChannel, true));

            y = y - 35;
            app.APIKeyLabel = uilabel(app.ControlPanel, 'Position', [10 y 110 22], 'Text', 'Read API Key:');
            app.APIKeyEditField = uieditfield(app.ControlPanel, 'text', 'Position', [130 y 160 22]);

            y = y - 45;
            app.StartDatePickerLabel = uilabel(app.ControlPanel, 'Position', [10 y 110 22], 'Text', 'Observation Date:');
            app.StartDatePicker = uidatepicker(app.ControlPanel, 'Position', [130 y 160 22], 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));

            y = y - 35;
            uilabel(app.ControlPanel, 'Position', [10 y 110 22], 'Text', 'Start Time:');
            app.StartHourDropDown = uidropdown(app.ControlPanel, 'Position', [130 y 50 22], 'Items', string(0:12), 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));
            app.MinDropDown = uidropdown(app.ControlPanel, 'Position', [190 y 50 22], 'Items', string(0:59), 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));
            app.AMPMSwitch = uiswitch(app.ControlPanel, 'slider', 'Items', {'AM', 'PM'}, 'Position', [260 y+5 40 15], 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));

            y = y - 45;
            app.DurationDropDownLabel = uilabel(app.ControlPanel, 'Position', [10 y 110 22], 'Text', 'Data Span:');
            app.DurationDropDown = uidropdown(app.ControlPanel, 'Position', [130 y 90 22], 'Items', {'Minute', 'Hour', 'Day', 'Week'}, 'Value', 'Day', 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));
            app.plotDuration = uieditfield(app.ControlPanel, 'numeric', 'Position', [230 y 60 22], 'Value', 1, 'Limits', [1 365], 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));

            y = y - 35;
            app.CompareLengthDropDownLabel = uilabel(app.ControlPanel, 'Position', [10 y 110 22], 'Text', 'Compare Period:');
            app.CompareLengthDropDown = uidropdown(app.ControlPanel, 'Position', [130 y 90 22], 'Items', {'None', 'Minute', 'Hour', 'Day', 'Week', 'Year'}, 'Value', 'Week', 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));
            app.plotLengthofComparison = uieditfield(app.ControlPanel, 'numeric', 'Position', [230 y 60 22], 'Value', 1, 'Limits', [1 365], 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));

            y = y - 35;
            app.RetimeDropDownLabel = uilabel(app.ControlPanel, 'Position', [10 y 110 22], 'Text', 'Data Retime:');
            app.RetimeDropDown = uidropdown(app.ControlPanel, 'Position', [130 y 160 22], 'Items', {'Raw', 'minutely', 'hourly', 'daily', 'weekly', 'monthly'}, 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));

            % --- Tabs for fields ---
            app.ChannelTabs = uitabgroup(app.ControlPanel, 'Position', [5 270 305 130]);

            % --- ML & Stats Controls ---
            y = 230;
            app.MLForecastLabel = uilabel(app.ControlPanel, 'Position', [10 y 150 22], 'Text', 'Enable ML Forecast:');
            app.MLForecastSwitch = uiswitch(app.ControlPanel, 'slider', 'Position', [170 y+5 45 20], 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));

            y = y - 35;
            app.AnomalyLabel = uilabel(app.ControlPanel, 'Position', [10 y 150 22], 'Text', 'Detect Anomalies:');
            app.AnomalySwitch = uiswitch(app.ControlPanel, 'slider', 'Position', [170 y+5 45 20], 'ValueChangedFcn', createCallbackFcn(app, @autoUpdate, true));

            % Stats Table
            app.StatsTable = uitable(app.ControlPanel, 'Position', [10 90 295 100]);
            app.StatsTable.ColumnName = {'Min', 'Max', 'Average'};
            app.StatsTable.ColumnWidth = {80, 80, 80};
            app.StatsTable.RowName = {};

            % --- Action Buttons ---
            app.UpdateButton = uibutton(app.ControlPanel, 'push', 'Text', 'GENERATE DASHBOARD', 'Position', [10 50 160 30], 'BackgroundColor', [0 0.6 0], 'FontColor', [1 1 1], 'FontWeight', 'bold', 'ButtonPushedFcn', createCallbackFcn(app, @updatePlots, true));
            app.ExportButton = uibutton(app.ControlPanel, 'push', 'Text', 'EXPORT', 'Position', [180 50 70 30], 'ButtonPushedFcn', createCallbackFcn(app, @exportReport, true));
            app.QuitButton = uibutton(app.ControlPanel, 'push', 'Text', 'QUIT', 'Position', [255 50 50 30], 'BackgroundColor', [0.6 0 0], 'FontColor', [1 1 1], 'ButtonPushedFcn', @(src,event) delete(app));

            app.ThemeLabel = uilabel(app.ControlPanel, 'Position', [10 15 100 22], 'Text', 'Dark Theme:');
            app.ThemeSwitch = uiswitch(app.ControlPanel, 'slider', 'Position', [120 18 45 20], 'ValueChangedFcn', @(src,event) applyTheme(app));

            app.DashboardPanel = uipanel(app.MainLayout, 'BorderType', 'none');
            app.DashboardPanel.Layout.Row = 1; app.DashboardPanel.Layout.Column = 2;

            app.StatusLabel = uilabel(app.MainFigure, 'Position', [325 5 700 20], 'Text', 'System Ready | OmniIoT Analytics Engine v1.1', 'FontSize', 10, 'FontWeight', 'bold');

            app.MainFigure.Visible = 'on';
        end
    end

    methods (Access = public)
        function app = OmniIoTAnalyst
            createComponents(app)
            registerApp(app, app.MainFigure)
            runStartupFcn(app, @startupFcn)
            if nargout == 0, clear app; end
        end
        function delete(app)
            delete(app.MainFigure)
        end
    end
end
