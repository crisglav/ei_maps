function plot_brain_hemispheres(values,srcatlas)
% plot_brain_hemispheres(values)
% 
% Plots left and right hemisphere meshes colored by 'values' per ROI,
% with a matching colorbar.
%
% INPUT:
%   values - numeric vector of length = number of ROIs, values to map to colors (e.g. [0 1])
%
% REQUIREMENTS:
%   - 'srcatlas' must be in the workspace with fields:
%       srcatlas.mesh.bnd(1) and srcatlas.mesh.bnd(2)
%       srcatlas.atlas.name (for nrois)
%   - FieldTrip function 'ft_plot_mesh' available

    left_hemi  = srcatlas.mesh.bnd(1);
    right_hemi = srcatlas.mesh.bnd(2);
    nrois = numel(srcatlas.atlas.name);
    
    % Validate input length
    assert(numel(values) == nrois, 'Length of values must match number of ROIs');
    
    values = values(:); % ensure column vector
    
    cmap = parula(256);
    
    % Map values → colormap indices
    cidx = round(rescale(values, 1, size(cmap,1)));
    cidx = max(1, min(size(cmap,1), cidx));
    
    % ROI → RGB color lookup
    roi2color = cmap(cidx, :);
    
    % Initialize vertex colors
    left_hemi.color  = zeros(numel(left_hemi.area), 3);
    right_hemi.color = zeros(numel(right_hemi.area), 3);
    
    % Logical masks for vertices belonging to ROIs
    L = left_hemi.area > 0;
    R = right_hemi.area > 0;
    
    % Assign colors per vertex
    left_hemi.color(L, :)  = roi2color(left_hemi.area(L), :);
    right_hemi.color(R, :) = roi2color(right_hemi.area(R), :);
    
    % Create figure
    figure;
    
    % Left hemisphere views
    ax1 = axes('Position', [0.00, 0.5, 0.6, 0.6]);
    hold(ax1, 'on');
    ft_plot_mesh(left_hemi, 'facecolor', [1 1 1]);
    material dull;
    lighting gouraud;
    view(115, 10);
    camlight;
    hold(ax1, 'off');
    axis(ax1, 'off');
    
    ax2 = axes('Position', [0.00, 0.0, 0.6, 0.6]);
    hold(ax2, 'on');
    ft_plot_mesh(left_hemi, 'facecolor', [1 1 1]);
    material dull;
    lighting gouraud;
    view(-115, 10);
    camlight;
    axis(ax2, 'off');
    hold(ax2, 'off');
    
    % Right hemisphere views
    ax3 = axes('Position', [0.4, 0.5, 0.6, 0.6]);
    hold(ax3, 'on');
    ft_plot_mesh(right_hemi, 'facecolor', [1 1 1]);
    material dull;
    lighting gouraud;
    view(-115, 10);
    camlight;
    rotate3d on;
    axis(ax3, 'off');
    hold(ax3, 'off');
    
    ax4 = axes('Position', [0.4, 0.0, 0.6, 0.6]);
    hold(ax4, 'on');
    ft_plot_mesh(right_hemi, 'facecolor', [1 1 1]);
    material dull;
    lighting gouraud;
    view(115, 10);
    camlight;
    rotate3d on;
    axis(ax4, 'off');
    hold(ax4, 'off');
    
    drawnow;
    
    % Add thick colorbar in its own invisible axes
    vmin = min(values, [], 'omitnan');
    vmax = max(values, [], 'omitnan');
    cbax = axes('Position', [0.90 0.15 0.04 0.7], 'Visible', 'off');
    colormap(cbax, cmap);
    caxis(cbax, [vmin vmax]);
    cb = colorbar(cbax);
    cb.LineWidth = 1.5;
    cb.FontSize = 12;
end
