function helperNNDPDDownloadData(subject)
%helperNNDPDDownloadData Download data files
%   helperNNDPDDownloadData downloads data files used by the
%   neural network DPD example.

%   Copyright 2021-2023 The MathWorks, Inc.

arguments
  subject (1,1) {mustBeMember(subject, ...
    ["dataprep","projection","undefined"])} = "undefined"
end

switch subject
  case "undefined"
    dataFileNames = "NNDPD_deeplearning_uploads_R2023a.zip";
    expFileNames = ["license.txt","savedDataNIVST100MHz.mat",...
      "savedTestResultsNIVST100MHz_R2023a.mat"];
  case "dataprep"
    dataFileNames = "NNDPD_training_data_Oct23.zip";
    expFileNames = ["license_training.txt","nndpdTrainingDataOct23.mat"];
  case "projection"
    dataFileNames = ["NNDPD_training_data_Oct23.zip"; ...
      "NNDPD_projection_data_Oct23.zip"];
    expFileNames = ["license_training.txt","nndpdTrainingDataOct23.mat"; ...
      "license_projection.txt","nndpdProjectionDataOct23.mat"];
end

for p=1:length(dataFileNames)
  dataFileName = dataFileNames(p);
  url = "https://www.mathworks.com/supportfiles/spc/NNDPD/" ...
    + dataFileName;

  dstFolder = pwd;

  helperDownloadDataFile(url, ...
    dataFileName, ...
    expFileNames(p,:), ...
    dstFolder);
end
end

function helperDownloadDataFile(url, archive, expFileNames, dstFolder)
%helperDownloadDataFile Download and uncompress data file from URL
%   helperDownloadDataFile(URL,DATAFILE,EXPFILES,DST) downloads and
%   uncompresses DATAFILE from URL to DST folder. EXPFILES is a list of
%   expected uncompressed files.

[~, ~, fExt] = fileparts(archive);

skipExtract = true;
for p=1:length(expFileNames)
  tmpFileName = fullfile(dstFolder, expFileNames{p});
  if ~exist(tmpFileName, "file")
    skipExtract = false;
    break
  end
end

if skipExtract
  fprintf("Files for %s already exist. Skipping download and extract.\n", ...
    archive)
else
  fprintf("Starting download of data files from:\n\t%s\n", url)
  fileFullPath = matlab.internal.examples.downloadSupportFile("spc/NNDPD",...
    archive);
  disp("Download complete. Extracting files.")
  switch fExt
    case {".tar", ".gz"}
      untar(fileFullPath, dstFolder);
    case ".zip"
      unzip(fileFullPath, dstFolder);
    otherwise
      error("Downloaded file has invalid file type.");
  end
  disp("Extract complete.")
 end
end