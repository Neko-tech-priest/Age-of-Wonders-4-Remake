const std = @import("std");
const math = std.math;
// const cos = math.cos
const pi: f32 = std.math.pi;
pub const mat4 = struct
{
	data: [16]f32,
	pub fn identity() void
	{
		.data[ 0] = 1;.data[ 1] = 0;.data[ 2] = 0;.data[ 3] = 0;
		.data[ 4] = 0;.data[ 5] = 1;.data[ 6] = 0;.data[ 7] = 0;
		.data[ 8] = 0;.data[ 9] = 0;.data[10] = 1;.data[11] = 0;
		.data[12] = 0;.data[13] = 0;.data[14] = 0;.data[15] = 1;
	}
	pub fn scale(self: *mat4, x: f32, y: f32, z: f32) void
	{
		self.*.data[ 0] = x;self.*.data[ 1] = 0;self.*.data[ 2] = 0;self.*.data[ 3] = 0;
		self.*.data[ 4] = 0;self.*.data[ 5] = y;self.*.data[ 6] = 0;self.*.data[ 7] = 0;
		self.*.data[ 8] = 0;self.*.data[ 9] = 0;self.*.data[10] = z;self.*.data[11] = 0;
		self.*.data[12] = 0;self.*.data[13] = 0;self.*.data[14] = 0;self.*.data[15] = 1;
	}
	pub fn translate(self: *mat4, x: f32, y: f32, z: f32) void
	{
		self.*.data[ 0] = 1;self.*.data[ 1] = 0;self.*.data[ 2] = 0;self.*.data[ 3] = 0;
		self.*.data[ 4] = 0;self.*.data[ 5] = 1;self.*.data[ 6] = 0;self.*.data[ 7] = 0;
		self.*.data[ 8] = 0;self.*.data[ 9] = 0;self.*.data[10] = 1;self.*.data[11] = 0;
		self.*.data[12] = x;self.*.data[13] = y;self.*.data[14] = z;self.*.data[15] = 1;
	}
	pub fn rotate(self: *mat4, angleGrad: f32, axis_of_rotation: u8) void
	{
		const angle = angleGrad*pi/180.0;
		if(axis_of_rotation == 'x')
		{
			self.*.data[ 0] = 1;self.*.data[ 1] = 0;          self.*.data[ 2] = 0;          self.*.data[ 3] = 0;
			self.*.data[ 4] = 0;self.*.data[ 5] = @cos(angle);self.*.data[ 6] = @sin(angle);self.*.data[ 7] = 0;
			self.*.data[ 8] = 0;self.*.data[ 9] =-@sin(angle);self.*.data[10] = @cos(angle);self.*.data[11] = 0;
			self.*.data[12] = 0;self.*.data[13] = 0;          self.*.data[14] = 0;          self.*.data[15] = 1;
		}
		else if(axis_of_rotation == 'y')
		{
			self.*.data[ 0] = @cos(angle);self.*.data[ 1] = 0;self.*.data[ 2] =-@sin(angle);self.*.data[ 3] = 0;
			self.*.data[ 4] = 0;          self.*.data[ 5] = 1;self.*.data[ 6] = 0;          self.*.data[ 7] = 0;
			self.*.data[ 8] = @sin(angle);self.*.data[ 9] = 0;self.*.data[10] = @cos(angle);self.*.data[11] = 0;
			self.*.data[12] = 0;          self.*.data[13] = 0;self.*.data[14] = 0;          self.*.data[15] = 1;
		}
		else if(axis_of_rotation == 'z')
		{
			self.*.data[ 0] = @cos(angle);self.*.data[ 1] = @sin(angle);self.*.data[ 2] = 0;self.*.data[ 3] = 0;
			self.*.data[ 4] =-@sin(angle);self.*.data[ 5] = @cos(angle);self.*.data[ 6] = 0;self.*.data[ 7] = 0;
			self.*.data[ 8] = 0;          self.*.data[ 9] = 0;          self.*.data[10] = 1;self.*.data[11] = 0;
			self.*.data[12] = 0;          self.*.data[13] = 0;          self.*.data[14] = 0;self.*.data[15] = 1;
		}
	}
	pub fn perspective(self: *mat4, angleGrad: f32, aspect: f32, n: f32, f: f32) void
	{
		const angle = angleGrad*pi/180.0;
		var i: usize = 0;
		while(i < 16) : (i+=1)
			self.*.data[i] = 0;
		self.*.data[ 0] = 1.0/(@tan(angle/2.0)*aspect);
		self.*.data[ 5] = 1.0/(@tan(angle/2.0));
		self.*.data[10] = f/(f-n);self.*.data[11] = 1;
		self.*.data[14] = -(f*n)/(f-n);// f / (-f/n + 1)
	}
// 	pub fn mul(m_1: mat4) void
// 	{
//
// 	}
};
pub fn mul(m_1: mat4, m_2: mat4) mat4
{
// 	_ = m_1;
// 	_ = m_2;
	var m_rez: mat4 = undefined;
	var x: usize = undefined;
	var y: usize = 0;
	while(y < 4)
	{
		x = 0;
		while(x < 4)
		{
			m_rez.data[4*y+x] =
			m_1.data[4*y+0]*m_2.data[4*0+x] +
			m_1.data[4*y+1]*m_2.data[4*1+x] +
			m_1.data[4*y+2]*m_2.data[4*2+x] +
			m_1.data[4*y+3]*m_2.data[4*3+x];
			x+=1;
		}
		y+=1;
	}
	return m_rez;
}
