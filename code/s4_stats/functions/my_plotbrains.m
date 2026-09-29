function my_plotbrains ( surfl, surfr, metric, colorlim, cmap)

% Sets the color limits.
if isempty(colorlim)
    colormin      = min ( min ( surfl.stat ), min ( surfr.stat ) );
    colormax      = max ( max ( surfl.stat ), max ( surfr.stat ) );
    if strcmp(metric, 'f statistic')
        colormin = 0;
        colormax = max(colormax, eps);
    else
        colormin      = min ( colormin, -colormax );
        colormax      = max ( colormax, -colormin );
    end
    colorlim      = [ colormin colormax ];    
end

% Plots the brain in the different views.
figure ( 'Units', 'centimeters', 'Position', [  0.0  2.0 17.0 10.0 ] )
if isempty(cmap)
    cmap = jet;
end
colormap(cmap);

axes ( 'Units', 'centimeters', 'Position', [  7.5  0.0  7.5  4.9 ] , 'Visible', 'off' )
ft_plot_mesh ( surfr, 'VertexColor', 'curv' )
ft_plot_mesh ( surfr, 'VertexColor', surfr.stat, 'FaceAlpha', surfr.mask, 'CLim', colorlim, 'AlphaLim', [ 0 1 ] )
axis tight
view ( -90, 0 )
material dull
delete ( findall ( gca, 'Type', 'light' ) )
camlight

axes ( 'Units', 'centimeters', 'Position', [  0.0  0.0  7.5  4.9 ] , 'Visible', 'off' )
ft_plot_mesh ( surfl, 'VertexColor', 'curv' )
ft_plot_mesh ( surfl, 'VertexColor', surfl.stat, 'FaceAlpha', surfl.mask, 'CLim', colorlim, 'AlphaLim', [ 0 1 ] )
axis tight
view ( +90, 0 )
material dull
delete ( findall ( gca, 'Type', 'light' ) )
camlight

axes ( 'Units', 'centimeters', 'Position', [  7.5  5.1  7.5  4.9 ], 'Visible', 'off' )
ft_plot_mesh ( surfr, 'VertexColor', 'curv' )
ft_plot_mesh ( surfr, 'VertexColor', surfr.stat, 'FaceAlpha', surfr.mask, 'CLim', colorlim, 'AlphaLim', [ 0 1 ] )
axis tight
view ( +90, 0 )
material dull
delete ( findall ( gca, 'Type', 'light' ) )
camlight

axes ( 'Units', 'centimeters', 'Position', [  0.0  5.1  7.5  4.9 ] , 'Visible', 'off' )
ft_plot_mesh ( surfl, 'VertexColor', 'curv' )
ft_plot_mesh ( surfl, 'VertexColor', surfl.stat, 'FaceAlpha', surfl.mask, 'CLim', colorlim, 'AlphaLim', [ 0 1 ] )
axis tight
view ( -90, 0 )
material dull
delete ( findall ( gca, 'Type', 'light' ) )
camlight

% colorbar ( 'Units', 'centimeters', 'Position', [ 15.0  0.1  0.6  9.8 ], 'XLim', colorlim, 'FontName', 'Roboto', 'FontSize', 10,'Box','off' )
colorbar ( 'Units', 'centimeters', 'Position', [ 15.0  2.5  0.6  4.9 ], 'XLim', colorlim, ...
    'FontName', 'Roboto', 'FontSize', 10, 'Box', 'off', 'Color', '#9d9d9d' )
xlabel ( findall ( gcf, 'Type', 'Colorbar' ), metric )

% axes ( 'Units', 'centimeters', 'Position', [  16.5  0.2  0.4 13.6 ], 'Visible', 'off' )
% text ( 0, 0, metric, 'FontWeight', 'bold', 'Rotation', 90, 'HorizontalAlign', 'center', 'VerticalAlign', 'middle' )
% xlim ( [ -1 +1 ] )
% ylim ( [ -1 +1 ] )
