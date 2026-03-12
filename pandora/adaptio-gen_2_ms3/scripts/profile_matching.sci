function [new_profile, new_abw, new_wire_tip_pos] = MatchProfiles(src_abw, src_profile, ref_abw, ref_profile, wire_tip_pos)
    new_profile = [];
    new_abw = [];
    wall_lim = 2.0e-3; //mm
    D_left = eye(2,2);
    D_right = eye(2,2);
    S_left = eye(2,2); //No deformation can be computed and should not be relevant
    S_right = eye(2,2);
    t_left = [0;0];
    t_right = [0;0];
    ang_left = 0;
    ang_right = 0;

    wall_height_left = src_abw(1,2) - src_abw(2,2);
    wall_height_right = src_abw(7,2) - src_abw(6,2);
    left_wall_remaining = wall_height_left > wall_lim;
    right_wall_remaining = wall_height_right > wall_lim;
    both_walls_remaining = left_wall_remaining & right_wall_remaining;

    if both_walls_remaining
      // Half profile matching
      [new_profile, new_abw, new_wire_tip_pos] = DoHalfProfileMatching(src_abw, src_profile, ref_abw, ref_profile, wire_tip_pos);
    else
      // Full profile matching
      [new_profile, new_abw, new_wire_tip_pos] = DoFullProfileMatching(src_profile, ref_profile, src_abw, wire_tip_pos);
    end

    new_profile = MergeBottom(new_profile, ref_profile, new_wire_tip_pos(1));

endfunction

function [new_profile, new_abw, new_wire_tip_pos] = DoHalfProfileMatching(src_abw, src_profile, ref_abw, ref_profile, wire_tip_pos)
    new_profile = [];
    // Get three reference points: top surface point, and ABWs on walls
    [src_left, src_right] = CreateRefPoints(src_abw, src_profile);
    [ref_left, ref_right] = CreateRefPoints(ref_abw, ref_profile);
    
    // Compute full deformation matrix (rotation, translation, deformation)
    [D_left,t_left]   = ComputeThreePointTransformation(src_left, ref_left);
    [D_right,t_right] = ComputeThreePointTransformation(src_right, ref_right);
    
    // Separate the rotation and deformation
    [R_left, S_left]   = Decompose(D_left);
    [R_right, S_right] = Decompose(D_right);

    // Ensure that rotation does not contain reflection
    Q = [ -1, 0 ; 0, 1 ];
    if det(R_left) < 0 then
        R_left = R_left * Q;
        S_left = Q * S_left;
    end
    if det(R_right) < 0 then
        R_right = R_right * Q;
        S_right = Q * S_right;
    end
    
    //Get the rotation angles from matrix to facilitate angle interpolation
    ang_left = atan(R_left(2,1), R_left(1,1));
    ang_right = atan(R_right(2,1), R_right(1,1));

    // Apply distortion to abw points
    def_abw_left  = D_left * src_abw(1:2,:)' + t_left * [1,1];
    def_abw_right = D_right * src_abw(6:7,:)' + t_right * [1,1];
    //def_abw_bottom = zeros(2,3);

    bottom = src_profile;
    k_bottom = find(src_profile(:,1) <= src_abw(2,1) & src_profile(:,1) >= src_abw(6,1));
    bottom = src_profile(k_bottom,:);

    left_side = src_profile(find(src_profile(:,1) > src_abw(2,1)),:);
    right_side = src_profile(find(src_profile(:,1) < src_abw(6,1)),:);

    // Distort bottom with interpolation between left and right sides.
    def_src_bottom = [];
    x_bottom_right = src_abw(6,1);
    bottom_width = src_abw(2,1) - src_abw(6,1);
    for i = 1:size(bottom,1)
        wi = (bottom(i,1) - x_bottom_right) / bottom_width; //Interpolation weight
        // //ang_interp = wi * ang_left + (1 - wi) * ang_right;
        // //ang_interp = ang_right + wi * (ang_left - ang_right);
        // delta = atan(sin(ang_left - ang_right), cos(ang_left - ang_right));
        // ang_interp = ang_right + wi * delta;

        // R_interp = [cos(ang_interp), -sin(ang_interp); sin(ang_interp), cos(ang_interp)];
        // S_interp = wi * S_left + (1 - wi) * S_right;
        // D_interp = R_interp * S_interp;
        D_interp = wi * D_left + (1 - wi) * D_right;
        t_interp = wi * t_left + (1 - wi) * t_right;
        
        dst_point = D_interp * bottom(i,:)' + t_interp;
        def_src_bottom(i,:) = dst_point';
    end

    // Apply transformations to abw bottom points
    def_abw_bottom = [];
    for i = 1:3
        wi = (src_abw(i+2,1) - x_bottom_right) / bottom_width;
        D_interp = wi * D_left + (1 - wi) * D_right;
        t_interp = wi * t_left + (1 - wi) * t_right;
        dst_point = D_interp * src_abw(i+2,:)' + t_interp;
        def_abw_bottom(i,:) = dst_point';
    end

    def_src_left = D_left * left_side' + repmat(t_left, 1, size(left_side,1));
    def_src_right = D_right * right_side' + repmat(t_right, 1, size(right_side,1));
    //new_profile = MergeBottom(def_src_bottom, ref_profile);
    new_profile = [def_src_left';def_src_bottom; def_src_right'];
    new_abw = [def_abw_left';def_abw_bottom;def_abw_right'];

    // Apply transformations to torch pos as well
    left_wall = Line2d(src_abw(1,:),src_abw(2,:));
    right_wall = Line2d(src_abw(7,:),src_abw(6,:));
    horizontal_line = Line2d(wire_tip_pos, wire_tip_pos + [1,0]);
    left_point = horizontal_line.Intersect(left_wall, %f, %t);
    right_point = horizontal_line.Intersect(right_wall, %f, %t);
    if left_point == [] | right_point == [] //When torch is above top surface
      left_point = src_abw(1,:);
      right_point = src_abw(7,:);
    end
    wi = (wire_tip_pos(1) - right_point(1)) / (left_point(1) - right_point(1));
    if wi < 0 then wi = 0; end
    if wi > 1 then wi = 1; end
    D_interp = wi * D_left + (1 - wi) * D_right;
    t_interp = wi * t_left + (1 - wi) * t_right
    new_wire_tip_pos = (D_interp * wire_tip_pos' + t_interp)';
    
endfunction

function [new_profile, new_abw, new_wire_tip_pos] = DoFullProfileMatching(src_profile, ref_profile, src_abw, wire_tip_pos)

    x_step = ref_profile(2,1) - ref_profile(1,1);
    Qx = [src_profile(1,1):x_step:src_profile($,1)]';
    nbr_q = length(Qx);
    x_torch = wire_tip_pos(1);
    Py = ref_profile(:,2); //Before weld
    Qy = interpln(flipdim(src_profile, 1)', flipdim(Qx,1)); //src_profile(:,2); //After weld
    Qy = flipdim(Qy',1);
    src_profile = [Qx, Qy]; // Resampled src profile

    //Mask out new bead region
    bead_half_width = 15e-3;
    k_bead = find(src_profile(:,1) > x_torch - bead_half_width & src_profile(:,1) < x_torch + bead_half_width);
    Qy(k_bead) = %nan;

    // Weights
    Pw = ones(Py);
    Qw = ones(Qy);

    // Match profiles roughly in x by computing NCC
    [ncc_raw, overlap] = NccWithGapsWeighted(Py, Qy, Pw, Qw);
    //ncc = ncc_raw .* overlap;
    ncc = ncc_raw;
    first_point_offset = src_profile(1,1) - ref_profile(1,1);
    [x_shift, ncc_max] = ComputeShiftFromNcc(ncc, first_point_offset);
    
    // Apply shift
    shifted_src_profile = src_profile;
    shifted_src_profile(:,1) = shifted_src_profile(:,1) + x_shift;
    shifted_wire_tip_pos = wire_tip_pos;
    shifted_wire_tip_pos(1) = shifted_wire_tip_pos(1) + x_shift;
    shifted_src_abw = src_abw;
    shifted_src_abw(:,1) = shifted_src_abw(:,1) + x_shift;

    // Refine match by ICP
    [R, t] = DoIcpWithTrimming(shifted_src_profile, ref_profile, x_torch);
    n_points = size(src_profile,1);
    transf_src_profile = R' * (shifted_src_profile' - repmat(t, 1, n_points));
    transf_wire_tip_pos = R' * (shifted_wire_tip_pos' - t);
    transf_src_abw = R' * (shifted_src_abw' - repmat(t, 1, size(src_abw,1)));

    //new_profile = MergeBottom(transf_src_profile, ref_profile);
    new_profile = transf_src_profile';
    new_wire_tip_pos = transf_wire_tip_pos;
    new_abw = transf_src_abw';

    // Evaluate the goodness of fit
    score = EvaluteMatch(new_profile, ref_profile);
    score.ncc = ncc_max;

endfunction

function [x_shift, max_ncc] = ComputeShiftFromNcc(ncc, first_point_offset)
    dncc = diffxy([1:length(ncc)],ncc); //Derivative of NCC
    dncc_range = [1:length(dncc) - 1]' - 1; 
    dncc_fraction = dncc_range ./ max(dncc_range);
    k_maxima = find(dncc(1:$-1) > 0 & dncc(2:$) < 0 & dncc_fraction > 0.2 & dncc_fraction < 0.8); // Roots of derivative <--> peaks in ncc
    [_, max_idx] = max(ncc(k_maxima));
    max_ncc = ncc_raw(k_maxima(max_idx));
    i_offset = k_maxima(max_idx) - (nbr_q - 1);
    x_shift = (i_offset * x_step) - first_point_offset ;
endfunction

function [score] = EvaluteMatch(new_profile, ref_profile)
    x_start = min(new_profile(1,1), ref_profile(1,1));
    x_stop = max(new_profile($,1), ref_profile($,1));
    k_new = new_profile(:,1) < x_start & new_profile(:,1) > x_stop;
    k_ref = ref_profile(:,1) < x_start & ref_profile(:,1) > x_stop;
    // Use only overlapping parts of profiles
    ref_profile2 = ref_profile(k_ref,:);
    new_profile2 = new_profile(k_new,:);
    // Use common x and resample
    Py = ref_profile2(:,2);
    Qx = ref_profile2(:,1); //Common x from ref
    Qy = interpln(flipdim(new_profile2, 1)', flipdim(Qx,1)); //After weld
    Qy = flipdim(Qy',1);
    new_profile2 = [Qx,Qy];
    x_torch = transf_wire_tip_pos(1);
    // Mask new bead region
    k_bead = find(Qx > x_torch - bead_half_width & Qx < x_torch + bead_half_width);
    Qy(k_bead) = %nan;
    Py(k_bead) = %nan;
    // Compute the scores
    [s_final, s_corr, s_rmse, neff] = ComputeScores(Py, Qy);
    score.final = s_final;
    score.corr = s_corr;
    score.rmse = s_rmse;
    score.neff = neff;

endfunction

function [merged_profile] = MergeBottom(new_profile, ref_profile, x_torch)
    
    // Resample new bottom on ref profile x values
    //x_common = new_bottom(:,1);
    x_max = min(max(ref_profile(:,1)), max(new_profile(:,1)));
    x_min = max(min(ref_profile(:,1)), min(new_profile(:,1)));
    k_max = find(ref_profile(:,1) < x_max, 1);
    if k_max == []
        k_max = 1;
    end
    k_min = find(ref_profile(:,1) < x_min, 1);
    if k_min == []
        k_min = size(ref_profile,1);
    else
        k_min = k_min - 1; //-1 due to the find condition above.
    end
    
    if k_max >= k_min then
        error("Bottom does not overlap previous profile.");
    end

    overlap_start_idx = k_max;
    try
    x_common = ref_profile(k_max:k_min,1);
    y_new = interpln(flipdim(new_profile',2), flipdim(x_common,1));
    catch
      pause
    end
    new_profile = [x_common,flipdim(y_new',1)]; // New bottom resampled on ref x values

    step_left = -1;
    step_right = 1;
    // [p_right, new_right_idx, ref_right_idx] = FindEdgeOfBead(new_profile, ref_profile, step_right, ref_offset, x_torch); //idx refers to ref profile
    // [p_left, new_left_idx, ref_left_idx]  =  FindEdgeOfBead(new_profile, ref_profile, step_left, ref_offset, x_torch);

    // The new bead (if present) should extend between idx_left and idx_right
    // Outside these indices the new profile is supposed to be unaffected by deposition --> take ref profile there.
    
    // To be precise, the new profile should merge with the ref profile at the 
    // intersection/extrapolation points p_right and p_left which are not part of
    // neither new or ref profiles. 
    
    // ref_profile(ref_left_idx,:)  = p_left;
    // ref_profile(ref_right_idx,:) = p_right;

    // merged_profile = new_profile(new_left_idx + 1 : new_right_idx - 1,:);
    // merged_profile = [ref_profile(1:ref_left_idx,:); merged_profile];
    // merged_profile = [merged_profile; ref_profile(ref_right_idx:$,:)];

    [p_right, right_idx] = FindEdgeOfBead2(new_profile, ref_profile, step_right, x_torch); //idx refers to ref profile
    [p_left, left_idx]  =  FindEdgeOfBead2(new_profile, ref_profile, step_left, x_torch);
    k_bead = (overlap_start_idx - 1) + [left_idx:right_idx]; // Indices rel. to original profiles
    merged_profile = ref_profile;
    merged_profile(k_bead, :) = new_profile([left_idx:right_idx], :);
    
endfunction

function [p_edge, merge_idx] = FindEdgeOfBead2(new_profile, ref_profile, step, x_torch)
    // Profiles must have same x values and same length
    d_lim_extrapolation = 0.7e-3; //Distance limit for attempting to extrapolate to old profile
    d_lim_edge = 0.3e-3; // Hard distance limit for assuming bead edge
    nbr_close_lim = 3;
    stop_idx = size(new_profile, 1);
    ref_stop_idx = size(ref_profile,1);
    x_step = ref_profile(1,1) - ref_profile(2,1);
    if step < 0 then
        ref_stop_idx = 1;
        stop_idx = 1;
    end

    k_max = find(new_profile(:,1) < x_torch, 1);
    d = new_profile(k_max,2) - ref_profile(k_max,2);

    p_prev = new_profile(k_max, :);
    q_prev = ref_profile(k_max, :);
    d_prev = %inf;
    p_curr = [];
    q_curr = [];
    d_curr = 0;
    prev_interp_dist = %inf;
    interp_dist = %inf;
    prev_merge_idx = stop_idx;
    merge_idx = stop_idx;
    new_line = Line2d([0,0],[0,0]); //Line segment on the new profile
    old_line = Line2d([0,0],[0,0]); //Line segment on the old profile
    p_edge = [];
    success = %f;
    nbr_close = 0;

    // Step along the new profile from the torch position towards edge
    for i = [k_max + step : step : stop_idx]
        i_ref = i;
        p_curr = new_profile(i, :);
        q_curr = ref_profile(i_ref, :);
        d_curr = p_curr(2) - q_curr(2);

        if i == stop_idx
            p_edge = ref_profile(i_ref, :);
            merge_idx = stop_idx;
            return;
        end

        // Skip until we are close enough to try extrapolation
        if d_curr > d_lim_extrapolation
            continue;
        end

        // Reached cross-over without interpolation
        // if d_curr < 0
        //     p_edge = ref_profile(i_ref, :);
        //     merge_idx = i_ref;
        //     return;
        // end
        
        // Attempt extrapolation
        new_line.SetEndPoints(p_prev, p_curr); // Extrapolation vector
        interp_dist = %inf;
        merge_idx = stop_idx;

        // Close enough to the ref profile
        // Start extrapolating to find intersection with ref profile
        for j = [i_ref : step : stop_idx]
            old_line.SetEndPoints(ref_profile(j-step,:), ref_profile(j,:));
            p_edge = new_line.Intersect(old_line, %f, %t);

            if p_edge == []
              continue;
            end

            // Found intersection, check how close it is and break regardless
            interp_dist = abs(p_edge(1) - p_curr(1));
            if interp_dist > abs(5 * x_step)
                // Extrapolation to long, abort search of ref segments
                interp_dist = %inf;
                p_edge = [];
                break;
            else
                // Extrapolation ok, abort search of ref segments
                merge_idx = j;
                break;
            end
        end

        // Count the number of subsequent close points have been encountered
        if d_curr < d_lim_edge
            nbr_close = nbr_close + 1;
        else
            nbr_close = 0;
        end

        // ==================================================
        // Conditions to break the search for bead edge

        // Had a valid intersection in prev iteration, but no more. 
        //if isinf(interp_dist) & ~isinf(prev_interp_dist)
            //merge_idx = int(prev_merge_idx + abs(prev_interp_dist / x_step) * step);
            //success = %t;
            //break;
        //end

        // Got a valid intersection this iteration, but worse than the previous one
        if ~isinf(interp_dist) & interp_dist >= prev_interp_dist
            merge_idx = int(prev_merge_idx + abs(prev_interp_dist / x_step) * step);
            success = %t;
            break;
        end

        // Extrapolation critera not met, but several subsequent points have been very close to ref.
        if nbr_close == nbr_close_lim 
            merge_idx = i;//i - nbr_close_lim * step;
            success = %t;
            break;
        end

        // Values to keep for next iteration
        d_prev = d_curr;
        p_prev = p_curr;
        q_prev = q_curr;
        prev_interp_dist = interp_dist;
        prev_merge_idx = merge_idx;
    end

    if success
        p_edge = ref_profile(merge_idx, :);
    else
        p_edge = ref_profile(stop_idx, :);
        merge_idx = stop_idx;
    end

endfunction

function [p_edge, new_merge_idx, ref_merge_idx] = FindEdgeOfBead(new_bottom, ref_profile, step, ref_offset, x_torch)
    
    // Both inputs must have the same x_values (and same size)
    // Move right from max diff point
    // Step gives the step size (and sign/dir). This can be used to skip points and control which edge to find. left<0, right>0
    // q: points on ref profile
    // p: points on new profile
    //TODO: Check that we are using the right units here. mm for the test data.
    d_lim = 0.5e-3; //Distance limit for attempting to extrapolate to old profile
    
    // Find the x with max diff between ref and new
    nbr_bottom = size(new_bottom,1);
    bottom_end_idx = ref_offset + nbr_bottom - 1;
    [d, k_max] = max(new_bottom(:,2) - ref_profile(ref_offset:bottom_end_idx,2));

    //mprintf("New bottom max index: %i\n", k_max)
    
    if k_max == 1 then
        k_max = 2;
    end
    
    if k_max == nbr_bottom
        k_max = nbr_bottom - 1;
    end
    
    stop_idx = size(new_bottom, 1);
    ref_stop_idx = size(ref_profile,1);
    if step < 0 then
        ref_stop_idx = 1;
        stop_idx = 1;
    end

    try
    p_prev = new_bottom(k_max, :);
    q_prev = ref_profile(k_max + ref_offset - 1, :);
    catch
      pause
    end

    d_prev = %inf;
    p_curr = [];
    q_curr = [];
    d_curr = 0;
    new_line = Line2d([0,0],[0,0]); //Line segment on the new profile
    old_line = Line2d([0,0],[0,0]); //Line segment on the old profile
    p_edge = [];
    new_merge_idx = stop_idx;
    ref_merge_idx = [];
    for i = [k_max + step : step : stop_idx]
        i_ref = ref_offset + i - 1;
        p_curr = new_bottom(i, :);
        q_curr = ref_profile(i_ref, :);
        d_curr = p_curr(2) - q_curr(2);
        
        // mprintf("Bottom index: %i\n",i)
        // mprintf("Vertical dist: %.3f\n", d_curr);
        if d_curr < d_lim | i == stop_idx
            
            // Handle the case when d_lim occurs after
//            if d_curr > d_prev
//                new_line.SetEndPoints(new_bottom(i - 2 * step), p_curr); // Extrapolation vector
//            end
            
            if d_curr < 0 then
                i_ref = i_ref - step; //Take one step back if we alread crossed the ref profile
            end
            
            // mprintf("Ref index: %i (%i)\n", i_ref, ref_stop_idx);
            new_line.SetEndPoints(p_prev, p_curr); // Extrapolation vector
            // mprintf("New start: %.2f, %.2f\n", new_line.GetStart()')
            // mprintf("New end: %.2f, %.2f\n", new_line.GetEnd()')
            
            for j = [i_ref + step : step : ref_stop_idx]

                old_line.SetEndPoints(ref_profile(j-step,:), ref_profile(j,:));
                // mprintf("Ref index: %i (%i)\n", j, ref_stop_idx);
                // mprintf("Old start: %.2f, %.2f\n", old_line.GetStart()')
                // mprintf("Old end: %.2f, %.2f\n", old_line.GetEnd()')
                p_edge = new_line.Intersect(old_line, %f, %t);
                if p_edge <> []
                    new_merge_idx = i;
                    ref_merge_idx = j;
                    break;
                end
            end
            // if p_edge == []
            //     error("Could not find edge of bead.");
            // end
            break;
        end
        
        d_prev = d_curr;
        p_prev = p_curr;
        q_prev = q_curr;
    end
    
    // Handle the case when the bead edge is on the groove wall, i.e. at stop_idx
    // Should not normally happen since the new and old profiles should approach
    // eachother regardless. Perhaps for near vertical walls.
  
    if p_edge == [] then
        p_edge = new_bottom(stop_idx,:);
        new_merge_idx = stop_idx;
        ref_merge_idx = ref_offset + new_merge_idx - 1
    end
    
endfunction

function [R, S] = Decompose(D)
    
    S = real(sqrt(D' * D)); //Symmetric part. Strain.
    R = D * inv(S); // Rotation part
    
endfunction

function [dst_points] = DeformPoints(D, t, src_points)
    
    dst_points = src_points * D'; //Mult. order to get the same dimensions out
    dst_points(:,1) = dst_points(:,1) + t(1);
    dst_points(:,2) = dst_points(:,2) + t(2);
    
endfunction

function [R, t] = ComputeTwoPointTransformation(src_points, ref_points)
    
    v_src = src_points(2,:) - src_points(1,:);
    v_ref = ref_points(2,:) - ref_points(1,:);
    v_ref = v_ref' ./ norm(v_ref);
    v_src = v_src' ./ norm(v_src);
    cos_ang = v_src' * v_ref; //Dot product
    sin_ang = det([v_src, v_ref]); //Determinant, signed area
    
    R = [cos_ang, -sin_ang; sin_ang, cos_ang];
    t = ref_points(1,:)' - src_points(1,:)';
    
endfunction

function [D,t] = ComputeThreePointTransformation(src_points, dst_points)
    //input: nx2 matrices
    A = [];
    b = [];
    for i = 1:size(src_points,1)
        A(2*i - 1,:) = [src_points(i,:),0,0,1,0];
        A(2*i,:)     = [0,0,src_points(i,:),0,1];
        b(2*i - 1)   = dst_points(i,1);
        b(2*i)       = dst_points(i,2);
    end
    try
    x = A\b;
    catch
      pause
    end
    D = matrix(x(1:4),2,2)'; // Deformation matrix. Including rotation
    t = x(5:6);
    
endfunction


function [ref_left, ref_right] = CreateRefPoints(abw, profile)
    
    len = 10e-3; //mm
    p2 = abw(1,:);
    v_top = profile(1,:) - p2;
    v_wall = abw(2,:) - p2;
    p1 = p2 + len * v_top ./ norm(v_top);
    p3 = p2 + len * v_wall ./ norm(v_wall);
    ref_left = [p1;p2;p3];
    
    p2 = abw(7,:);
    v_top = profile($,:) - p2;
    v_wall = abw(6,:) - p2;
    p1 = p2 + len * v_wall ./ norm(v_wall);
    p3 = p2 + len * v_top ./ norm(v_top);
    ref_right = [p1;p2;p3];
    
endfunction

function [ref_points] = CreateTopRefPoints(abw, profile, side)
    
    len = 10; //mm
    if side == "left"
        p2 = abw(1,:);
        v_top = profile(1,:) - p2;
        p1 = p2 + len * v_top ./ norm(v_top);
        ref_points = [p2;p1];
    else
        p2 = abw(7,:);
        v_top = profile($,:) - p2;
        p3 = p2 + len * v_top ./ norm(v_top);
        ref_points = [p2;p3];
    end
endfunction


classdef Line2d 
    properties (private)
        start = [];
        direction = [];
        len = [];
    end
    
    methods (public)
        function Line2d(start_point, end_point)
            this.start = start_point(:);
            this.len = norm(end_point - start_point);
            this.direction = (end_point(:) - start_point(:)) ./ this.len;
        endfunction
        
        function [start_point] = GetStart()
            start_point = this.start;
        endfunction
        
        function [end_point] = GetEnd()
            end_point = this.start + this.direction * this.len;
        endfunction
        
        function [] = SetEndPoints(start_point, end_point)
            this.start = start_point(:);
            this.len = norm(end_point - start_point);
            this.direction = (end_point(:) - start_point(:)) ./ this.len;
        endfunction
        
        function [vec] = ToVector()
            vec = this.direction * this.len;
        endfunction
        
        function [p_int] = Intersect(line, consider_len_this, consider_len_other)

            p_int = [];
            //Solve p + tr = q + us for weights t and u ==> intersection
            p = this.GetStart();
            r = this.ToVector();
            q = line.GetStart();
            s = line.ToVector();
            
            if det([r,s]) == 0 //Non-intersecting. Additional contraints can be checked to see if they are overlapping
                return;
            end
            
            t = det([q-p, s]) / det([r,s]);
            u = det([q-p, r]) / det([r,s]);
            
            if consider_len_this //Check that intersection is within line1
                if t < 0 | t > 1
                    return; //Not a valid intersection
                end
            end
            if consider_len_other //Check that intersection is within line1
                if u < 0 | u > 1
                    return; //Not a valid intersection
                end
            end
            
            p_int = p + t * r;
            
        endfunction
    end
end

function [R,t] = SolveRigid(P, Q)
    
    // Weights (ones for now)
    //w = ones(size(P,1),1);
    
    // Centroids
    muP = mean(P, "r");
    muQ = mean(Q, "r");
    
    // Centered data
    Pc = [P(:,1) - muP(1), P(:,2) - muP(2)];
    Qc = [Q(:,1) - muQ(1), Q(:,2) - muQ(2)];
    
    // Weighted cross-covariance H = Pc' * diag(w) * Qc
    H = Pc' * Qc;
    
    //SVD
    [U,S,V] = svd(H);
    Vt = V'
    //Avoid reflection
    R = Vt' * U';
    if det(R) < 0 
        Vt(2,:) = -Vt(2,:);
        R = Vt' * U'
    end
    
    // Translation
    t = muQ' - R * muP';
    
endfunction

function [min_indices] = FindNearestNeighbors(P,Q)
    
    // Brute force approach --> compute all distances between points
    P2 = sum(P.^2, "c"); //Nx1
    Q2 = sum(Q.^2, "c")'; //1xM
    P2 = repmat(P2, 1, size(Q,1));//NxM
    Q2 = repmat(Q2, size(P,1), 1)
    D2 = P2 + Q2 - 2 * P * Q'; // (a-b)^2 = a^2 + b^2 - 2ab
    
    [_, min_indices] = min(D2,"c");
    
endfunction


function [c, Lvec] = NccWithGapsWeighted(Py, Qy, Pw, Qw)
    // Weighted normalized cross-correlation with NaN gaps ignored.
    // Signed shift s:
    //   s < 0 : P shifted right by -s (Q left)
    //   s = 0 : aligned
    //   s > 0 : Q shifted right by  s
    //
    // OUTPUTS:
    //   c    : vector of length length(Py)+length(Qy)-1, correlation per shift
    //   Lvec : same length as c, the raw overlap length at each shift
    //          (L counts indices BEFORE removing NaNs or invalid weights)
    //
    // Index mapping: c(s + length(Qy)) corresponds to shift s.

    // Ensure column vectors
    Py = Py(:);  Qy = Qy(:);
    Pw = Pw(:);  Qw = Qw(:);

    // Size checks
    if length(Pw) <> length(Py) then
        error("Pw must match Py in length.");
    end
    if length(Qw) <> length(Qy) then
        error("Qw must match Qy in length.");
    end

    nbr_p = length(Py);
    nbr_q = length(Qy);

    // Full correlation length
    M = nbr_p + nbr_q - 1;
    c    = %nan * ones(M, 1);
    Lvec = zeros(M, 1); // integer overlap lengths (0..min(nbr_p,nbr_q))

    // Index offset so that shift s maps to c(s + offset)
    offset = nbr_q; // 1-based: shift 0 -> index = nbr_q

    //-----------------------------------------
    // Loop 1: NEGATIVE SHIFTS (s = -(nbr_q-1) : -1)
    //-----------------------------------------
    if nbr_q > 1 then
        for s = -(nbr_q - 1) : -1
            idx = s + offset;  // 1..(nbr_q-1)
            [r, L] = wcorr_overlap(Py, Qy, Pw, Qw, s);
            c(idx)    = r;
            Lvec(idx) = L;
        end
    end

    //-----------------------------------------
    // Loop 2: NON-NEGATIVE SHIFTS (s = 0 : +(nbr_p-1))
    //-----------------------------------------
    for s = 0 : (nbr_p - 1)
        idx = s + offset;  // nbr_q .. M
        [r, L] = wcorr_overlap(Py, Qy, Pw, Qw, s);
        c(idx)    = r;
        Lvec(idx) = L;
    end
endfunction


// --------------------------------------------------------
// Helper: weighted correlation & overlap length at signed shift
// --------------------------------------------------------
function [r, L] = wcorr_overlap(Py, Qy, Pw, Qw, s)
    // Computes:
    //   r : weighted Pearson correlation for the given signed shift s
    //   L : raw overlap length (count of indices before NaN/weight masking)
    //
    // Weights are combined by product: w = Pw .* Qw.
    //
    // SHIFT CONVENTION (1-based indexing):
    //   s >= 0: Q shifted right by s.
    //           L = min(nbr_p - s, nbr_q).
    //           P indices: (s+1):(s+L),  Q indices: 1:L
    //   s <  0: P shifted right by -s (Q left by -s).
    //           k = -s; L = min(nbr_p, nbr_q - k).
    //           P indices: 1:L,           Q indices: (k+1):(k+L)

    // Ensure column vectors
    Py = Py(:);  Qy = Qy(:);
    Pw = Pw(:);  Qw = Qw(:);

    nbr_p = length(Py);
    nbr_q = length(Qy);

    // Determine raw overlap given s
    if s >= 0 then
        L = min(nbr_p - s, nbr_q);
        if L <= 0 then
            r = %nan; return;
        end
        p_start = s + 1;  p_end = p_start + L - 1;
        q_start = 1;      q_end = L;
    else
        k = -s;
        L = min(nbr_p, nbr_q - k);
        if L <= 0 then
            r = %nan; return;
        end
        p_start = 1;      p_end = L;
        q_start = k + 1;  q_end = q_start + L - 1;
    end

    // Slice values and weights for the raw overlap window
    p  = Py(p_start:p_end);
    q  = Qy(q_start:q_end);
    wp = Pw(p_start:p_end);
    wq = Qw(q_start:q_end);

    // Mask invalid items: NaN values/weights or non-positive weights
    valid = ~isnan(p) & ~isnan(q) & ~isnan(wp) & ~isnan(wq) & (wp > 0) & (wq > 0);

    if sum(valid) < 2 then
        r = %nan; return;
    end

    // Apply mask
    p  = p(valid);
    q  = q(valid);
    wp = wp(valid);
    wq = wq(valid);

    // Combine weights (product rule)
    w = wp .* wq;

    sW = sum(w);
    if sW <= 0 then
        r = %nan; return;
    end

    // Weighted means
    mu_p = sum(w .* p) / sW;
    mu_q = sum(w .* q) / sW;

    pc = p - mu_p;
    qc = q - mu_q;

    // Weighted covariance and variances (normalized by sum weights)
    cov_w = sum(w .* pc .* qc) / sW;
    var_p = sum(w .* pc .* pc) / sW;
    var_q = sum(w .* qc .* qc) / sW;

    denom = sqrt(var_p) * sqrt(var_q);

    if (denom == 0) | (isinf(denom)) then
        r = %nan;
    else
        r = cov_w / denom;
    end
    
endfunction


function [s_final, s_corr, s_rmse, neff] = ComputeScores(P, Q, alpha, L0)
    // alpha in [0,1], L0 is a length scale for optional overlap penalty
    if argn(2) < 3 then alpha = 0.5; end
    if argn(2) < 4 then L0 = 0; end // 0 disables penalty

    ok = ~isnan(P) & ~isnan(Q);
    neff = sum(ok);
    if neff < 2 then s_final = %nan; s_corr = %nan; s_rmse = %nan; return; end

    p = P(ok); q = Q(ok);

    // --- correlation part (unweighted)
    mu_p = mean(p); mu_q = mean(q);
    pc = p - mu_p; qc = q - mu_q;
    vp = sum(pc.^2); vq = sum(qc.^2);
    denom = sqrt(vp) * sqrt(vq);
    if denom == 0 then
        s_corr = %nan;
    else
        r = sum(pc .* qc) / denom;
        s_corr = (r + 1) / 2;
    end

    // --- RMSE part with robust normalization
    rmse = sqrt(mean((p - q).^2));
    // Z = [p; q];
    Z = p;
    medZ = median(Z);
    madZ = median(abs(Z - medZ));
    S = 1.4826 * madZ;
    if isinf(S) | S <= 0 then
        S = max(abs([p; q]));
        if isinf(S) | S <= 0 then
            s_rmse = %nan;
        else
            s_rmse = max(0, 1 - rmse / (S + %eps));
        end
    else
        s_rmse = max(0, 1 - rmse / (S + %eps));
    end

    // --- combine, with graceful fallback if one component is NaN
    if isinf(s_corr) & isinf(s_rmse) then
        s_base = %nan;
    elseif isinf(s_corr) then
        s_base = s_rmse;
    elseif isinf(s_rmse) then
        s_base = s_corr;
    else
        s_base = alpha * s_corr + (1 - alpha) * s_rmse;
    end

    if isinf(s_base) then
        s_final = %nan; return;
    end

    // Optional overlap penalty to discourage short overlaps
    if L0 > 0 then
        pi = min(1, neff / max(1, L0));
        s_final = s_base * pi;
    else
        s_final = s_base;
    end
endfunction


function [R, t] = DoIcpWithTrimming(src_profile, ref_profile, x_torch)
    
    bead_half_widht = 10; //mm
    trim_ratio = 0.7;
    max_iters = 50;
    R = eye(2,2);
    t = [0;0];

    // Select the subset where profiles overlap in x 
    // To avoid large distance between neighbors when profile are of different length
    x_start = min(src_profile(1,1), ref_profile(1,1));
    x_stop = max(src_profile($,1), ref_profile($,1));
    k_src = src_profile(:,1) < x_start & src_profile(:,1) > x_stop;
    k_ref = ref_profile(:,1) < x_start & ref_profile(:,1) > x_stop;
    
    Q = src_profile(k_src,:); //After weld
    P = ref_profile(k_ref,:); //Before weld
    n_points = size(P,1);
    
    for i = 1:max_iters
        
        P_trans = (R * P' + repmat(t, 1, n_points))';
        x_trans_torch = x_torch + t(1); // Ensure torch is translated to the same pos on profile
        min_indices = FindNearestNeighbors(P_trans, Q);
        Q_corr = Q(min_indices, :);
        squared_dists = sum((Q_corr - P_trans).^2, "c");
        idx_trim = int(size(P_trans,1) * trim_ratio);
        [_, k_sorted] = gsort(squared_dists, 'g', "i");
        k_inliers = k_sorted(1:idx_trim);
        
        P_i = P_trans(k_inliers,:);
        Q_i = Q_corr(k_inliers,:);
        
        [R_new, t_new] = SolveRigid(P_i, Q_i);
        R = R_new * R;
        t = R_new * t + t_new;
        
    end
    
    
endfunction
