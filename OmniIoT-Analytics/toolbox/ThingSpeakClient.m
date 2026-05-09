classdef ThingSpeakClient < handle
    % ThingSpeakClient - Client class to interact with ThingSpeak API.
    % Part of OmniIoT Analytics project.

    properties (Access = private)
        BaseURL = "https://api.thingspeak.com/"
    end

    methods
        function info = getChannelInfo(obj, channelID, apiKey)
            % Query ThingSpeak REST API for channel metadata.
            info.channelName = "";
            info.fieldNames = repmat("", 1, 8);
            info.fieldEnabled = false(1, 8);

            try
                url = obj.BaseURL + "channels/" + string(channelID) + "/feeds.json?results=0";
                if strlength(apiKey) > 0
                    url = url + "&api_key=" + apiKey;
                end
                data = webread(url);
                channel = data.channel;
                info.channelName = string(channel.name);

                for i = 1:8
                    fieldKey = "field" + string(i);
                    if isfield(channel, fieldKey) && ~isempty(channel.(fieldKey))
                        info.fieldEnabled(i) = true;
                        info.fieldNames(i) = string(channel.(fieldKey));
                    end
                end
            catch err
                error("OmniIoT:ThingSpeakClient:ReadError", ...
                    "Could not read channel info: " + string(err.message));
            end
        end

        function myData = fetchData(obj, query)
            % Fetch data from ThingSpeak based on a query structure.
            % query should have: .channelID, .APIKey, .startDate, .endDate, .fieldsList
            
            try
                myData = thingSpeakRead(query.channelID, ...
                    'ReadKey', query.APIKey, ...
                    'DateRange', [query.startDate query.endDate], ...
                    'Fields', query.fieldsList, ...
                    'OutputFormat', 'Timetable');

            catch readingError
                error("OmniIoT:ThingSpeakClient:FetchError", ...
                    "Data error for that time interval: " + readingError.message);
            end

            if isempty(myData)
                error("OmniIoT:ThingSpeakClient:NoData", "No Data for that time interval.");
            end
        end
    end
end
