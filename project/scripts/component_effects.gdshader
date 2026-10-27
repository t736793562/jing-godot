shader_type canvas_item;
uniform bool is_shadow=false;
uniform vec4 sample_region=vec4(0.0,0.0,1.0,1.0);
uniform vec2 component_size=vec2(1.0);
uniform vec2 output_size=vec2(1.0);
uniform float padding=0.0;
uniform float blur_sigma=5.0;
uniform vec4 shadow_color=vec4(0.0,0.0,0.0,0.28);
uniform float fade_start=1.0;
uniform float fade_bottom_px=0.0;
uniform float fade_edge_px=0.0;
uniform bool alpha_from_rgb=false;
uniform float alpha_subtract=0.0;
uniform float alpha_multiply=1.0;
varying vec4 incoming_color;
void vertex(){incoming_color=COLOR;}
void fragment(){
 if(is_shadow){
  vec2 local=(UV*output_size-vec2(padding))/component_size;
  float sum=0.0;float weight_sum=0.0;
  // Bounded Gaussian sampling; visual equivalence to Pillow blur remains a separate acceptance check.
  for(int y=-5;y<=5;y++){
   for(int x=-5;x<=5;x++){
    vec2 delta=vec2(float(x),float(y))*blur_sigma*0.6;
    float weight=exp(-dot(delta,delta)/(2.0*blur_sigma*blur_sigma));
    vec2 q=local+delta/component_size;
    float alpha=0.0;
    if(q.x>=0.0&&q.y>=0.0&&q.x<=1.0&&q.y<=1.0)alpha=texture(TEXTURE,sample_region.xy+q*sample_region.zw).a;
    sum+=alpha*weight;weight_sum+=weight;
   }
  }
  COLOR=vec4(shadow_color.rgb,shadow_color.a*sum/weight_sum)*incoming_color;
 }else{
  vec4 color=texture(TEXTURE,UV)*incoming_color;
  vec2 local=(UV-sample_region.xy)/sample_region.zw;
  if(alpha_from_rgb){vec3 rgb=texture(TEXTURE,UV).rgb;color.a=clamp((min(min(rgb.r,rgb.g),rgb.b)-alpha_subtract/255.0)*alpha_multiply,0.0,1.0)*incoming_color.a;}
  if(fade_start<1.0)color.a*=1.0-clamp((local.y-fade_start)/(1.0-fade_start),0.0,1.0);
  if(fade_bottom_px>0.0)color.a*=clamp((1.0-local.y)*component_size.y/fade_bottom_px,0.0,1.0);
  if(fade_edge_px>0.0){vec2 edge=min(local,vec2(1.0)-local)*component_size;color.a*=clamp(edge.x/fade_edge_px,0.0,1.0)*clamp(edge.y/fade_edge_px,0.0,1.0);}
  COLOR=color;
 }
}
