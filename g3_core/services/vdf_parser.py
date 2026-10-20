from __future__ import annotations

import logging


logger = logging.getLogger("g3.vdf_parser")


class VDFError(ValueError):
	pass


def parse_vdf(text: str) -> dict:
	"""把 VDF（Valve Data Format）文本解析成嵌套 dict。

	VDF 大致像 JSON 但不一样：
	- 没有逗号分隔
	- key 和 value 都用双引号
	- 可以嵌套（value 是 { ... } 块）
	- 支持 // 单行注释
	- 字符串里的 \" 是转义引号

	同一层出现重复 key 时，后者覆盖前者（VDF 实际数据里很少见）。
	"""
	if not text:
		return {}
	# 顶层可能有多段；返回第一段的结果
	root: dict = {}
	_stack: list[list] = [[root, None]]
	pos = 0
	length = len(text)

	def cur() -> list:
		return _stack[-1]

	while pos < length:
		ch = text[pos]

		# 注释
		if ch == "/" and pos + 1 < length and text[pos + 1] == "/":
			nl = text.find("\n", pos)
			pos = length if nl < 0 else nl + 1
			continue

		# 字符串 token
		if ch == '"':
			token, pos = _read_quoted(text, pos)
			frame = cur()
			parent = frame[0]
			if frame[1] is None:
				# 还缺 key → 这个 token 是 key
				frame[1] = token
			else:
				# 已有 key → 这个 token 是 value
				parent[frame[1]] = token
				frame[1] = None
			continue

		# 块的开始
		if ch == "{":
			frame = cur()
			parent = frame[0]
			key = frame[1]
			frame[1] = None
			child: dict = {}
			if key is not None:
				parent[key] = child
			_stack.append([child, None])
			pos += 1
			continue

		# 块的结束
		if ch == "}":
			if len(_stack) <= 1:
				# 多余的 }：忽略，别让整份文件解析失败
				pos += 1
				continue
			popped = _stack.pop()
			_frame_key = popped[1]
			_frame_dict = popped[0]
			parent_frame = cur()
			parent = parent_frame[0]
			if _frame_key is not None:
				parent[_frame_key] = _frame_dict
			pos += 1
			continue

		# 其他字符（空白、逗号等）一律跳过
		pos += 1

	return root


def _read_quoted(text: str, pos: int) -> tuple[str, int]:
	"""从 text[pos] == '"' 开始读一个带引号的 token，返回 (内容, 新位置)。"""
	length = len(text)
	i = pos + 1
	buf: list[str] = []
	while i < length:
		ch = text[i]
		if ch == "\\" and i + 1 < length:
			# 转义：\" → " ；\\ → \ ；其余原样保留后一个字符
			esc = text[i + 1]
			buf.append(esc if esc in ('"', "\\") else ch + esc)
			i += 2
			continue
		if ch == '"':
			return "".join(buf), i + 1
		buf.append(ch)
		i += 1
	# 没闭合：把读到的内容当作 token（容错）
	return "".join(buf), i
