function TE=AddGitInfoToSessionData(TE)
% If the protocol and Bpod is version-controlled by Git or Github, insert
% the following data into the SessionData.Info:
%   - the remote branch name,
%   - the Git SHA1 hash of the most recent commit, and
%   - the url of corresponding remote repository, if one exists.
%
% Created by Antonio Lee
% On 2022-09-22


% Insert Protocol Git Info
global BpodSystem
gitInfo = getGitInfo();

if ~isempty(gitInfo)
    TE.Info.SessionProtocolBranchName = gitInfo.branch;
    TE.Info.SessionProtocolBranchHash = gitInfo.hash;
    TE.Info.SessionProtocolRemoteBranchName = gitInfo.remote;
    TE.Info.SessionProtocolBranchURL = gitInfo.url;
end

% Insert Bpod Git Info
WorkingDir = cd(BpodSystem.Path.BpodRoot);
gitInfo = getGitInfo();

if ~isempty(gitInfo)
    TE.Info.BpodBranchName = gitInfo.branch;
    TE.Info.BpodBranchHash = gitInfo.hash;
    TE.Info.BpodRemoteBranchName = gitInfo.remote;
    TE.Info.BpodBranchURL = gitInfo.url;
end

cd(WorkingDir);
end