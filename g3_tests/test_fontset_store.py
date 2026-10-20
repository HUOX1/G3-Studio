"""T01：FontsetStore 字体组别 ID 路径安全测试。

只用临时目录与临时数据，不接触 %LOCALAPPDATA% 真实数据。
使用标准库 unittest（安装 pytest 后同样可直接收集运行）。
运行：.venv\\Scripts\\python.exe -m unittest g3_tests.test_fontset_store -v
"""
from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path

from g3_core.services.fontset_store import (
	FontsetStore,
	is_valid_fontset_id,
	make_default_fontset,
)


def _make_store(tmp: Path) -> FontsetStore:
	return FontsetStore(tmp / "fontsets")


class FontsetIdValidationTests(unittest.TestCase):
	"""is_valid_fontset_id 的白名单单元行为。"""

	def test_accepts_legal_ids(self) -> None:
		legal = [
			"default",
			"3f8a2b1c-4e5f-4a1b-8c2d-9e0f1a2b3c4d",  # create() 的 uuid4 形态
			"a",
			"Z9",
			"A.b_c-9",
			"a" * 100,  # 上限长度
		]
		for value in legal:
			with self.subTest(value=value):
				self.assertTrue(is_valid_fontset_id(value))

	def test_rejects_traversal_and_separators(self) -> None:
		bad = [
			"",
			"   ",
			"\t",
			"..",
			"../evil",
			"a/../b",
			"a/b",
			"..\\evil",
			"a\\..\\b",
			"a\\b",
			"C:\\evil",
			"C:/evil",
			"C:evil",
			"/abs",
			"\\abs",
			"//share",
			"\\\\srv\\share",
		]
		for value in bad:
			with self.subTest(value=value):
				self.assertFalse(is_valid_fontset_id(value))

	def test_rejects_windows_illegal_names(self) -> None:
		bad = [
			"CON",
			"con",
			"Nul",
			"AUX",
			"COM1",
			"com9",
			"LPT1",
			"lpt4",
			"CON.json",  # 文件名会变成 CON.json.json，仍按保留名拒绝
			"a<b",
			"a>b",
			"a:b",
			'a"b',
			"a|b",
			"a?b",
			"a*b",
			"a\nb",
			"a\x00b",
			"a\x1fb",
			".hidden",
			"-lead",
			"x" * 101,  # 超长
		]
		for value in bad:
			with self.subTest(value=value):
				self.assertFalse(is_valid_fontset_id(value))


class FontsetStorePathSafetyTests(unittest.TestCase):
	"""越界 ID 在各操作中被拒绝，且不触及字体目录之外的文件。"""

	def setUp(self) -> None:
		self._tmp = tempfile.TemporaryDirectory()
		self.addCleanup(self._tmp.cleanup)
		self.tmp = Path(self._tmp.name)
		self.outside = self.tmp / "outside"
		self.outside.mkdir()
		self.genuine = self.outside / "genuine.json"
		self.genuine.write_text('{"keep": true}', encoding="utf-8")
		self.store = _make_store(self.tmp)

	def _assert_outside_untouched(self) -> None:
		self.assertEqual(
			self.genuine.read_text(encoding="utf-8"), '{"keep": true}'
		)
		self.assertEqual(
			sorted(p.name for p in self.outside.glob("*")),
			["genuine.json"],
		)

	def test_save_rejects_escape_ids(self) -> None:
		for bad in ["../evil", "..\\evil", "C:\\evil", "a/b", str(self.genuine)]:
			with self.subTest(value=bad):
				with self.assertRaises(ValueError):
					self.store.save(bad, "x", {})
		self.assertFalse((self.store.root / "evil.json").exists())
		self._assert_outside_untouched()

	def test_get_escape_id_falls_back_to_default(self) -> None:
		fs = self.store.get("..\\outside\\genuine", "movies")
		self.assertEqual(fs.id, "default")
		self.assertEqual(fs.fields, make_default_fontset("movies").fields)
		self._assert_outside_untouched()

	def test_delete_escape_id_returns_false(self) -> None:
		self.assertFalse(self.store.delete("..\\outside\\genuine"))
		self.assertTrue(self.genuine.exists())
		self._assert_outside_untouched()

	def test_rename_escape_id_raises_value_error(self) -> None:
		with self.assertRaises(ValueError):
			self.store.rename("..\\outside\\genuine", "new")
		self.assertTrue(self.genuine.exists())
		self._assert_outside_untouched()

	def test_create_with_escape_copy_from_uses_default_fields(self) -> None:
		fs = self.store.create(
			"副本", copy_from="..\\outside\\genuine", scope="movies"
		)
		self.assertTrue(is_valid_fontset_id(fs.id))
		self.assertEqual(fs.fields, make_default_fontset("movies").fields)
		self._assert_outside_untouched()

	def test_symlink_escape_is_blocked(self) -> None:
		target = self.outside / "target.json"
		target.write_text('{"secret": 1}', encoding="utf-8")
		link = self.store.root / "linkid.json"
		try:
			os.symlink(target, link)
		except (OSError, NotImplementedError):
			self.skipTest("当前环境无权限创建符号链接，跳过 symlink 用例")
		try:
			# get：指向外部文件的链接被拒，回退默认
			self.assertEqual(self.store.get("linkid", "movies").id, "default")
			# save：拒绝写入
			with self.assertRaises(ValueError):
				self.store.save("linkid", "n", {})
			# delete：拒绝删除，链接与目标都原样保留
			self.assertFalse(self.store.delete("linkid"))
			self.assertTrue(link.is_symlink())
			self.assertEqual(target.read_text(encoding="utf-8"), '{"secret": 1}')
		finally:
			if link.is_symlink():
				os.unlink(link)  # 只清理测试自建的链接

	def test_hardlink_escape_is_blocked(self) -> None:
		target = self.outside / "target.json"
		target.write_text('{"secret": 1}', encoding="utf-8")
		link = self.store.root / "linkid.json"
		try:
			os.link(target, link)
		except (OSError, NotImplementedError):
			self.skipTest("当前环境无法创建硬链接，跳过 hardlink 用例")
		try:
			# get：指向外部文件的硬链接被拒，回退默认
			self.assertEqual(self.store.get("linkid", "movies").id, "default")
			# save：拒绝写入
			with self.assertRaises(ValueError):
				self.store.save("linkid", "n", {})
			# delete：拒绝删除，链接与目标都原样保留
			self.assertFalse(self.store.delete("linkid"))
			self.assertTrue(link.exists())
			self.assertEqual(target.read_text(encoding="utf-8"), '{"secret": 1}')
		finally:
			if link.exists():
				os.unlink(link)  # 只清理测试自建的硬链接

	def test_list_skips_unsafe_entries(self) -> None:
		fs = self.store.create("正常组", scope="movies")
		# 非法 ID 文件名（-bad 不匹配白名单）应被跳过
		(self.store.root / "-bad.json").write_text(
			'{"id": "-bad", "name": "x"}', encoding="utf-8"
		)
		# 指向外部文件的硬链接应被跳过，且外部内容不受影响
		link = self.store.root / "hardid.json"
		try:
			os.link(self.genuine, link)
		except (OSError, NotImplementedError):
			link = None
		try:
			items = self.store.list_fontsets()
			ids = {x.id for x in items}
			self.assertIn(fs.id, ids)  # 正常组别仍正常列出
			self.assertIn("default", ids)
			self.assertNotIn("-bad", ids)
			self.assertNotIn("hardid", ids)
			self.assertGreaterEqual(len(items), 3)  # default×2 + 正常组
			self.assertEqual(
				self.genuine.read_text(encoding="utf-8"), '{"keep": true}'
			)
		finally:
			if link is not None and link.exists():
				os.unlink(link)

	def test_list_skips_symlink_entries(self) -> None:
		link = self.store.root / "linkid.json"
		try:
			os.symlink(self.genuine, link)
		except (OSError, NotImplementedError):
			self.skipTest("当前环境无权限创建符号链接，跳过 symlink 列表用例")
		try:
			self.store.create("正常组", scope="movies")
			ids = {x.id for x in self.store.list_fontsets()}
			self.assertNotIn("linkid", ids)
			self.assertEqual(
				self.genuine.read_text(encoding="utf-8"), '{"keep": true}'
			)
		finally:
			if link.is_symlink():
				os.unlink(link)


class FontsetStoreRegressionTests(unittest.TestCase):
	"""原有正常功能不受影响的回归。"""

	def setUp(self) -> None:
		self._tmp = tempfile.TemporaryDirectory()
		self.addCleanup(self._tmp.cleanup)
		self.tmp = Path(self._tmp.name)
		self.store = _make_store(self.tmp)

	def test_default_group_is_protected(self) -> None:
		with self.assertRaises(ValueError):
			self.store.save("default", "x", {})
		self.assertFalse(self.store.delete("default"))
		with self.assertRaises(ValueError):
			self.store.rename("default", "x")
		self.assertEqual(self.store.get("default", "games").id, "default")

	def test_valid_roundtrip(self) -> None:
		fs = self.store.create("我的组别", scope="movies")
		self.assertTrue(is_valid_fontset_id(fs.id))
		self.assertEqual(fs.scope, "movies")
		self.assertTrue((self.store.root / f"{fs.id}.json").is_file())

		got = self.store.get(fs.id, "movies")
		self.assertEqual(got.id, fs.id)
		self.assertEqual(got.name, "我的组别")

		renamed = self.store.rename(fs.id, "新名字")
		self.assertEqual(renamed.name, "新名字")
		self.assertEqual(self.store.get(fs.id, "movies").name, "新名字")

		# 保存合法 ID 正常写回
		saved = self.store.save(fs.id, "新名字", got.fields, "movies")
		self.assertEqual(saved.id, fs.id)

		self.assertTrue(self.store.delete(fs.id))
		self.assertFalse((self.store.root / f"{fs.id}.json").exists())
		self.assertEqual(self.store.get(fs.id, "movies").id, "default")

	def test_games_scope_create_get_save_delete(self) -> None:
		# 注：rename 对 games 组别存在既有缺陷（T09/F-01，rename 未传
		# scope），不在 T01 范围内，此处只验证 T01 未破坏其余操作。
		fs = self.store.create("我的游戏组", scope="games")
		got = self.store.get(fs.id, "games")
		self.assertEqual(got.id, fs.id)
		saved = self.store.save(fs.id, "我的游戏组", got.fields, "games")
		self.assertEqual(saved.id, fs.id)
		self.assertTrue(self.store.delete(fs.id))
		self.assertEqual(self.store.get(fs.id, "games").id, "default")

	def test_list_contains_both_default_scopes(self) -> None:
		items = self.store.list_fontsets()
		ids_scopes = {(x.id, x.scope) for x in items}
		self.assertIn(("default", "movies"), ids_scopes)
		self.assertIn(("default", "games"), ids_scopes)

	def test_invalid_id_never_crashes_get(self) -> None:
		for bad in ["", "  ", "..", "a/b", "CON"]:
			with self.subTest(value=bad):
				fs = self.store.get(bad, "movies")
				self.assertEqual(fs.id, "default")


if __name__ == "__main__":
	unittest.main()
