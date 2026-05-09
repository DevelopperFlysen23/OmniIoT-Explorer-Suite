classdef DataAnalytics
    % DataAnalytics - Static utility class for IoT data analysis.
    
    methods (Static)
        function stats = calculateStats(data)
            % Returns a table of statistics for each numeric variable in the timetable.
            varNames = data.Properties.VariableNames;
            stats = table('Size', [numel(varNames), 4], ...
                'VariableTypes', {'double', 'double', 'double', 'double'}, ...
                'VariableNames', {'Min', 'Max', 'Mean', 'StdDev'}, ...
                'RowNames', varNames);
            
            for i = 1:numel(varNames)
                colData = data{:, i};
                if isnumeric(colData)
                    stats.Min(i) = min(colData, [], 'omitnan');
                    stats.Max(i) = max(colData, [], 'omitnan');
                    stats.Mean(i) = mean(colData, 'omitnan');
                    stats.StdDev(i) = std(colData, 'omitnan');
                end
            end
        end

        function [futureTime, futureData] = predictTrend(time, data, numPoints)
            % ML Linear Regression to predict future points.
            % time: datetime array, data: numeric array, numPoints: how many points to predict
            
            if isempty(data) || numel(data) < 2
                futureTime = []; futureData = []; return;
            end
            
            % Convert time to numeric (seconds from start)
            x = seconds(time - time(1));
            y = data;
            
            % Remove NaNs for regression
            valid = ~isnan(y);
            x = x(valid); y = y(valid);
            
            if numel(y) < 2
                futureTime = []; futureData = []; return;
            end

            % Linear fit: y = p1*x + p2
            p = polyfit(x, y, 1);
            
            % Generate future time points
            dt = mean(diff(x));
            if isnan(dt), dt = 60; end % default 1 min
            
            lastX = x(end);
            futureX = lastX + (dt * (1:numPoints))';
            
            futureData = polyval(p, futureX);
            futureTime = time(1) + seconds(futureX);
        end

        function anomalyIdx = detectAnomalies(data, threshold)
            % Detect anomalies using Z-Score. 
            if nargin < 2, threshold = 3; end
            
            mu = mean(data, 'omitnan');
            sigma = std(data, 'omitnan');
            
            if sigma == 0
                anomalyIdx = false(size(data));
                return;
            end
            
            zScores = abs(data - mu) ./ sigma;
            anomalyIdx = zScores > threshold;
        end

        function report = generateSummaryText(stats, forecastVal, anomaliesFound)
            % Generates a human-readable description of the data.
            report = "--- OMNIIOT ANALYTICS REPORT ---\n";
            report = report + "Generated on: " + string(datetime('now')) + "\n\n";
            
            rows = stats.Properties.RowNames;
            for i = 1:numel(rows)
                varName = rows{i};
                valMin = stats.Min(i);
                valMax = stats.Max(i);
                valAvg = stats.Mean(i);
                
                report = report + "SENSOR: " + varName + "\n";
                report = report + sprintf("- Range: From %.2f to %.2f\n", valMin, valMax);
                report = report + sprintf("- Average Level: %.2f\n", valAvg);
                
                % Add descriptive analysis
                if valMax > valAvg * 1.5
                    report = report + "- Observation: High volatility or significant peaks detected.\n";
                elseif (valMax - valMin) < (valAvg * 0.05)
                    report = report + "- Observation: Signal is very stable with minimal fluctuation.\n";
                else
                    report = report + "- Observation: Normal operating behavior.\n";
                end
                
                if ~isempty(forecastVal)
                    diff = forecastVal - valAvg;
                    trend = "stable";
                    if diff > 0.5, trend = "increasing"; 
                    elseif diff < -0.5, trend = "decreasing"; end
                    report = report + sprintf("- AI Forecast: The trend is %s (Predicted next: %.2f)\n", trend, forecastVal);
                end
                
                if anomaliesFound
                    report = report + "- ALERT: Anomalies were detected in this period! Manual check recommended.\n";
                end
                report = report + "\n";
            end
            report = report + "--- END OF REPORT ---";
        end
    end
end
