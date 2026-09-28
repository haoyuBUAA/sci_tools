function merge_rinex3_obs(file_dir)
%%  Usage:
%   file_dir='Z:\sci\iono\rinex\';
%   merge_rinex3_obs(file_dir);
%   Created by Haoyu Wang 2026
%%
% 如果未传入路径，默认使用当前目录
if nargin < 1
    file_dir = './';
end

% 1. 查找所有 .22O 文件
files = dir(fullfile(file_dir, '*.*22O'));
if isempty(files)
    error('未找到匹配的 .22O RINEX 观测文件！');
end

% 提取文件名并排序（保证按 0-9, A-X 顺序）
file_names = {files.name};
file_names = sort(file_names);
num_files = length(file_names);
fprintf('共找到 %d 个文件，准备开始合并...\n', num_files);

% 2. 读取所有文件的内容
first_header_lines = {}; % 第一个文件的 Header 原始行
all_body_lines = {};     % 所有文件的观测数据行

first_obs_str = '';
last_obs_str = '';

for i = 1:num_files
    file_path = fullfile(file_dir, file_names{i});
    fid = fopen(file_path, 'r');
    if fid == -1
        warning('无法打开文件: %s，已跳过', file_names{i});
        continue;
    end

    is_header = true;

    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line)
            break;
        end

        % 如果还在文件头部分
        if is_header
            if i == 1
                first_header_lines{end+1} = line; %#ok<AGROW>
            end

            % 记录第一个文件的起始时间
            if contains(line, 'TIME OF FIRST OBS') && isempty(first_obs_str)
                first_obs_str = line;
            end

            % 更新最后一个文件的结束时间
            if contains(line, 'TIME OF LAST OBS')
                last_obs_str = line;
            end

            % 遇到文件头结束标志
            if contains(line, 'END OF HEADER')
                is_header = false;
            end
        else
            % 文件头之后全部为数据体，直接收集
            all_body_lines{end+1} = line; %#ok<AGROW>
        end
    end
    fclose(fid);
end

% 3. 修正第一个文件的 Header 中的起止时间
for k = 1:length(first_header_lines)
    if contains(first_header_lines{k}, 'TIME OF LAST OBS') && ~isempty(last_obs_str)
        % 替换为最后一个文件的 LAST OBS 时间
        first_header_lines{k} = last_obs_str;
    end
end

% 4. 生成输出文件名（例如：SEPT0910.22O -> SEPT0910_merged.22O）
[~, name_no_ext, ext] = fileparts(file_names{1});
output_filename = fullfile(file_dir, [name_no_ext(1:end-1), '0_merged', ext]);

% 5. 写入合并后的文件
out_fid = fopen(output_filename, 'w');
if out_fid == -1
    error('无法创建输出文件: %s', output_filename);
end

% 写入修正后的 Header
for k = 1:length(first_header_lines)
    fprintf(out_fid, '%s\n', first_header_lines{k});
end

% 写入拼接好的 Data Body
for k = 1:length(all_body_lines)
    fprintf(out_fid, '%s\n', all_body_lines{k});
end

fclose(out_fid);
fprintf('合并完成！新文件已保存至: %s\n', output_filename);
end