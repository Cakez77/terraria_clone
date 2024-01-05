
orthographic_projection :: (left : float, right : float, top : float, bottom : float) -> Matrix4
{
  result : Matrix4;
  // result.aw = -(right + left) / (right - left); 
  // result.bw = (top + bottom) / (top - bottom);
  // result.cw = 0.0f; // Near Plane
  result._41 = -(right + left) / (right - left); 
  result._42 = (top + bottom) / (top - bottom);
  result._34 = 0.0; // Near Plane
  result.coef[0][0] = 2.0 / (right - left);
  result.coef[1][1] = 2.0 / (top - bottom);
  result.coef[2][2] = 1.0 / (1.0 - 0.0);
  result.coef[3][3] = 1.0;

  return result;
}

// #############################################################################
//                           Perlin Noise
// #############################################################################
/* Function to linearly interpolate between a0 and a1
 * Weight w should be in the range [0.0, 1.0]
 */
interpolate :: (a0 : float, a1 : float, w : float) -> float
{
    /* // You may want clamping by inserting:
     * if (0.0 > w) return a0;
     * if (1.0 < w) return a1;
     */
    return (a1 - a0) * w + a0;
    /* // Use this cubic interpolation [[Smoothstep]] instead, for a smooth appearance:
     * return (a1 - a0) * (3.0 - w * 2.0) * w * w + a0;
     *
     * // Use [[Smootherstep]] for an even smoother result with a second derivative equal to zero on boundaries:
     * return (a1 - a0) * ((w * (w * 6.0 - 15.0) + 10.0) * w * w * w) + a0;
     */
}

/* Create pseudorandom direction vector
 */
random_gradient :: (ix : int, iy : int) -> Vector2
{
    // No precomputed gradients mean this works for any number of grid coordinates
    w :: 8 * size_of(u32);
    s :: w / 2; // rotation width
    a := ix;
    b := iy;
    a *= 3284157443; 
    b ^= a << s | a >> w-s;
    b *= 1911520717; 
    a ^= b << s | b >> w-s;
    a *= 2048419325;
    random := a * (3.14159265 / ~((~cast(u64)0) >> 1)); // in [0, 2*Pi]
    v : Vector2 = .{0, 0};
    v.x = xx cos(random); 
    v.y = xx sin(random);
    return v;
}

// Computes the dot product of the distance and gradient vectors.
dot_grid_gradient :: (ix : int, iy : int, x : float, y : float) -> float
{
    // Get gradient from integer coordinates
    gradient := random_gradient(ix, iy);

    // Compute the distance vector
    dx := x - cast(float)ix;
    dy := y - cast(float)iy;

    // Compute the dot-product
    return (dx*gradient.x + dy*gradient.y);
}

// Compute Perlin noise at coordinates x, y
perlin_noise :: (x : float, y : float) -> float
{
    // Determine grid cell coordinates
    x0 := cast(int)floor(x);
    x1 := x0 + 1;
    y0 := cast(int)floor(y);
    y1 := y0 + 1;

    // Determine interpolation weights
    // Could also use higher order polynomial/s-curve here
    sx := x - cast(float)x0;
    sy := y - cast(float)y0;

    // Interpolate between grid point gradients
    n0 := dot_grid_gradient(x0, y0, x, y);
    n1 := dot_grid_gradient(x1, y0, x, y);
    ix0 := interpolate(n0, n1, sx);

    n0 = dot_grid_gradient(x0, y1, x, y);
    n1 = dot_grid_gradient(x1, y1, x, y);
    ix1 := interpolate(n0, n1, sx);

    value := interpolate(ix0, ix1, sy);
    // Will return in range -1 to 1. To make it in range 0 to 1, multiply by 0.5 and add 0.5
    // value *= 0.5;
    // value += 0.5;
    return value; 
}

point_in_rect :: (point : Vector2, rect : Rect) -> bool
{
  return point.x >= rect.x &&
         point.x <= rect.x + rect.w &&
         point.y >= rect.y &&
         point.y <= rect.y + rect.h;
}

// #############################################################################
//                           Actual Perlin Noise?
// #############################################################################
SEED:int = 0;

hash : [] int = .[208,34,231,213,32,248,233,56,161,78,24,140,71,48,140,254,245,255,247,247,40,
                  185,248,251,245,28,124,204,204,76,36,1,107,28,234,163,202,224,245,128,167,204,
                  9,92,217,54,239,174,173,102,193,189,190,121,100,108,167,44,43,77,180,204,8,81,
                  70,223,11,38,24,254,210,210,177,32,81,195,243,125,8,169,112,32,97,53,195,13,
                  203,9,47,104,125,117,114,124,165,203,181,235,193,206,70,180,174,0,167,181,41,
                  164,30,116,127,198,245,146,87,224,149,206,57,4,192,210,65,210,129,240,178,105,
                  228,108,245,148,140,40,35,195,38,58,65,207,215,253,65,85,208,76,62,3,237,55,89,
                  232,50,217,64,244,157,199,121,252,90,17,212,203,149,152,140,187,234,177,73,174,
                  193,100,192,143,97,53,145,135,19,103,13,90,135,151,199,91,239,247,33,39,145,
                  101,120,99,3,186,86,99,41,237,203,111,79,220,135,158,42,30,154,120,67,87,167,
                  135,176,183,191,253,115,184,21,233,58,129,233,142,39,128,211,118,137,139,255,
                  114,20,218,113,154,27,127,246,250,1,8,198,250,209,92,222,173,21,88,102,219];

noise2 :: (x : int, y : int) -> int 
{
    tmp := hash[(y + SEED) % 256];
    return hash[(tmp + x) % 256];
}

lin_inter :: (x : float, y : float, s : float) -> float
{
    return x + s * (y-x);
}

smooth_inter :: (x : float, y : float , s : float) -> float
{
    return lin_inter(x, y, s * s * (3.0 - 2.0 * s));
}

noise2d :: (x : float, y : float) -> float
{
    x_int := cast(int)x;
    y_int := cast(int)y;
    x_frac : float = x - cast(float)x_int;
    y_frac : float = y - cast(float)y_int;
    s := noise2(x_int, y_int);
    t := noise2(x_int+1, y_int);
    u := noise2(x_int, y_int+1);
    v := noise2(x_int+1, y_int+1);
    low := smooth_inter(cast(float)s, cast(float)t, x_frac);
    high := smooth_inter(cast(float)u, cast(float)v, x_frac);
    return smooth_inter(low, high, y_frac);
}

perlin2d :: (x : float, y : float, freq : float, depth : int) -> float
{
    xa := x*freq;
    ya := y*freq;
    amp := 1.0;
    fin := 0.0;
    div := 0.0;

    for i: 0..(depth - 1)
    {
      div += 256 * amp;
      fin += noise2d(xa, ya) * amp;
      amp /= 2;
      xa *= 2;
      ya *= 2;
    }
    // for(i=0; i<depth; i++)
    // {
    //     div += 256 * amp;
    //     fin += noise2d(xa, ya) * amp;
    //     amp /= 2;
    //     xa *= 2;
    //     ya *= 2;
    // }

    return fin/div;
}