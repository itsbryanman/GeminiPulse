feat: enhance gpulse with subdirectory support, improved indexing, and better UX

## Major Features Added

### 🚀 Subdirectory Support
- **Smart project root detection**: Automatically finds `.git` and `.pulse` directories in parent directories
- **Run from anywhere**: Execute `gpulse` commands from any subdirectory within a project
- **Consistent cache keys**: Maintains relative paths for cache compatibility

### 📁 Targeted Indexing
- **Directory-specific indexing**: Use `--dir <path>` to index only specific directories
- **Faster processing**: Skip unnecessary files by targeting specific code areas
- **Flexible paths**: Support both relative and absolute directory paths
- **Examples**:
  ```bash
  gpulse index --dir src/           # Index only source code
  gpulse index --dir tests/         # Index only test files  
  gpulse index --dir cmd/services/  # Index specific service
  ```

### 🔍 Enhanced File Filtering
- **Comprehensive exclusions**: Skip build artifacts, dependencies, and system files
- **Smart defaults**: Ignore `.github/`, `node_modules/`, `dist/`, `build/`, etc.
- **Config files**: Skip `.gitignore`, `.dockerignore`, lock files, etc.
- **Binary files**: Exclude executables, libraries, archives, and minified files

### ⚡ Deep Indexing by Default
- **Better context**: Default to detailed code analysis instead of basic summaries
- **File-type awareness**: Specialized prompts for code vs config files
- **Code map generation**: Automatic project structure documentation
- **Backward compatibility**: `--simple` flag for basic indexing when needed

### 🛠️ Improved Error Handling
- **Better validation**: Check directory existence and git repository status
- **Clear error messages**: Helpful feedback for common issues
- **Graceful fallbacks**: Handle edge cases and missing dependencies

### 📋 Usage Examples
```bash
# Index entire project (deep analysis by default)
gpulse index

# Index specific directory with deep analysis
gpulse index --dir cmd/services/korl-acsg

# Index specific directory with simple analysis
gpulse index --dir src/ --simple

# Chat from any subdirectory
cd cmd/services/korl-acsg
gpulse chat

# Ask questions about specific code areas
gpulse ask "How does the authentication work in this service?"
```

## Technical Improvements
- **Robust path handling**: Proper absolute/relative path conversion
- **Cache consistency**: Maintains existing cache structure
- **Performance optimization**: Faster indexing with targeted directories
- **Better prompts**: More detailed and useful AI analysis

## Breaking Changes
- **Deep indexing is now default**: Use `--simple` for basic indexing
- **Improved exclusions**: Some files that were previously indexed may now be skipped

## Migration Guide
- Existing caches remain compatible
- No changes needed for existing workflows
- New `--dir` option available for faster, targeted indexing 